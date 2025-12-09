# Horizontal Pod Autoscaler (HPA) - Complete Setup with Scale Down
*Automated scaling based on CPU/Memory metrics with intelligent scale-down behavior*

```
┌─────────────────────────────────────────────────────────┐
│                  HPA Scale Down Behavior                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐   High Load   ┌─────────────┐         │
│  │  2 Pods     │ ─────────────► │  10 Pods    │         │
│  │ (Min)       │                │ (Max)       │         │
│  └─────────────┘                └─────────────┘         │
│         ▲                         ▲                      │
│         │                         │                      │
│    Scale Down                 Scale Up                   │
│  (Low Resource Usage)    (High Resource Usage)           │
│                                                         │
│  CPU/Memory < 50% Utilization     CPU/Memory > 50%      │
│                                                         │
│  Default cooldown: 300 seconds                          │
│  (5 minutes before scaling down)                        │
└─────────────────────────────────────────────────────────┘
```

## HPA Scale Down Configuration

HPA automatically **scales down** pods when resource usage drops below the target threshold. By default, it waits 5 minutes (300 seconds) after scaling up before considering scaling down to avoid rapid fluctuations.

---

## 1. Deployment with Resource Limits

### **nginx-deployment.yml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3  # Initial replicas (HPA will adjust this)
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:  # Minimum resources guaranteed
            cpu: "100m"      # 0.1 CPU core
            memory: "128Mi"  # 128 MB RAM
          limits:    # Maximum resources allowed
            cpu: "500m"      # 0.5 CPU core
            memory: "512Mi"  # 512 MB RAM
```

## 2. Service Exposure

### **nginx-service.yml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

## 3. HPA with Scale Down Configuration

### **nginx-hpa-scale-down.yml**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 2    # Minimum pods (scale down to this)
  maxReplicas: 10   # Maximum pods (scale up to this)
  
  # Scale down behavior configuration
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 minutes before scaling down
      policies:
      - type: Percent
        value: 50    # Remove up to 50% of current replicas
        periodSeconds: 60  # Every 60 seconds
  
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Scale down when CPU < 50%
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 50  # Scale down when Memory < 50%
```

## 4. Install Metrics Server (Required for HPA)

```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for kubeadm clusters
kubectl patch deployment metrics-server -n kube-system \
  --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Verify metrics
kubectl top nodes
kubectl top pods
```

## 5. Test Scale Down Behavior

### **Deploy and Monitor:**
```bash
# Deploy all components
kubectl apply -f nginx-deployment.yml
kubectl apply -f nginx-service.yml
kubectl apply -f nginx-hpa-scale-down.yml

# Watch initial state
kubectl get hpa
kubectl get pods

# Create load to trigger scale up
k6 run --vus 1000 --duration 2m test.js

# Watch scale up
watch -n 2 kubectl get hpa,pods

# After load stops, watch scale down
# HPA will wait 300 seconds (5 min) then scale down pods
watch -n 10 kubectl get hpa
```

## 6. Load Test Script for Scale Up/Down Testing

### **scale-test.js**
```javascript
import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  stages: [
    // Phase 1: Low load (should stay at min replicas)
    { duration: '30s', target: 10 },
    
    // Phase 2: High load (should scale up)
    { duration: '2m', target: 1000 },
    
    // Phase 3: Very high load (should scale to max)
    { duration: '3m', target: 2000 },
    
    // Phase 4: Drop to low load (should scale down after 5 min)
    { duration: '30s', target: 10 },
    
    // Phase 5: Monitor scale down
    { duration: '10m', target: 10 }
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],
  },
};

export default function () {
  http.get('http://<NODE_IP>:30080/');
  sleep(Math.random() * 3);
}
```

## 7. Monitoring Scale Down Events

```bash
# Watch HPA events
kubectl describe hpa nginx-hpa | grep -A10 -B10 "Events"

# Check current metrics
kubectl get hpa -o wide

# Monitor pod count over time
watch -n 5 'kubectl get pods | grep nginx | wc -l'

# Check metrics directly
kubectl top pods -l app=nginx

# View HPA decision logs
kubectl logs -n kube-system deployment/hpa-controller-manager | tail -50
```

## 8. Advanced Scale Down Tuning

### **Custom Scale Down Policy:**
```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait 5 minutes
    policies:
    - type: Pods
      value: 1           # Remove 1 pod at a time
      periodSeconds: 60  # Every minute
    - type: Percent
      value: 10          # Or remove 10% of pods
      periodSeconds: 60  # Every minute
    
  scaleUp:
    stabilizationWindowSeconds: 0  # Scale up immediately
    policies:
    - type: Pods
      value: 4           # Add 4 pods at a time
      periodSeconds: 10  # Every 10 seconds
    - type: Percent
      value: 100         # Or double the pods
      periodSeconds: 10  # Every 10 seconds
```

## 9. Verify Scale Down is Working

```bash
# 1. Create initial load to scale up
echo "Creating load to scale up pods..."
k6 run --vus 1500 --duration 3m test.js

# 2. Check pods scaled up
echo "Current pods:"
kubectl get pods | grep nginx | wc -l

# 3. Stop load and monitor scale down
echo "Stopping load. Scale down will begin in 5 minutes..."
echo "Monitoring pod count every 30 seconds:"

for i in {1..20}; do
  POD_COUNT=$(kubectl get pods -l app=nginx 2>/dev/null | grep -c "Running")
  echo "Minute $((i/2)): $POD_COUNT pods running"
  
  # Show HPA status
  kubectl get hpa nginx-hpa -o=custom-columns=NAME:.metadata.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,CURRENT:.status.currentReplicas,DESIRED:.status.desiredReplicas,CPU:.status.currentCPUUtilizationPercentage
  
  sleep 30
done

echo "Scale down complete. Should be at min replicas (2)"
```

## 10. Troubleshooting Scale Down Issues

### **If HPA doesn't scale down:**
```bash
# 1. Check current metrics
kubectl describe hpa nginx-hpa

# 2. Check if CPU usage is below threshold
kubectl top pods -l app=nginx

# 3. Check metrics server
kubectl get pods -n kube-system | grep metrics
kubectl logs -n kube-system deployment/metrics-server

# 4. Check HPA controller logs
kubectl logs -n kube-system deployment/hpa-controller-manager | grep -i "scaledown"

# 5. Force scale down (emergency only)
kubectl scale deployment nginx-deployment --replicas=2
```

### **Common Scale Down Problems:**
```bash
# Problem: HPA shows <unknown> for metrics
# Solution: Fix metrics server
kubectl delete pod -n kube-system -l k8s-app=metrics-server
sleep 30
kubectl top pods

# Problem: Scale down too aggressive
# Solution: Increase stabilization window
kubectl patch hpa nginx-hpa --type='json' -p='[{"op": "replace", "path": "/spec/behavior/scaleDown/stabilizationWindowSeconds", "value": 600}]'

# Problem: Scale down not happening
# Solution: Check resource requests/limits
kubectl describe deployment nginx-deployment | grep -A5 "Resources"
```

## 11. Complete Automation Script

### **auto-scale-test.sh**
```bash
#!/bin/bash
# Test HPA scale up and down

echo "=== HPA Scale Up/Down Test ==="

# Clean up
kubectl delete deployment nginx-deployment 2>/dev/null
kubectl delete hpa nginx-hpa 2>/dev/null
kubectl delete svc nginx-service 2>/dev/null

# Deploy
echo "Deploying nginx with HPA..."
kubectl apply -f nginx-deployment.yml
kubectl apply -f nginx-service.yml
kubectl apply -f nginx-hpa-scale-down.yml

# Wait for pods
echo "Waiting for pods..."
kubectl wait --for=condition=ready pod -l app=nginx --timeout=60s

# Get service URL
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
NODE_PORT=30080

echo "Service: http://$NODE_IP:$NODE_PORT"

# Initial state
echo -e "\nInitial State (min replicas):"
kubectl get hpa
kubectl get pods -l app=nginx

# Scale up test
echo -e "\n=== Starting Scale Up Test ==="
echo "Running high load for 3 minutes..."
k6 run --quiet --vus 1500 --duration 3m test.js &

# Monitor scale up
echo "Monitoring scale up (30s intervals):"
for i in {1..6}; do
  sleep 30
  PODS=$(kubectl get pods -l app=nginx 2>/dev/null | grep -c "Running")
  echo "  After $((i*30)) seconds: $PODS pods"
done

# Scale down test
echo -e "\n=== Starting Scale Down Test ==="
echo "Load stopped. Scale down will begin after 5 minute cooldown..."
echo "Monitoring every 30 seconds for 10 minutes:"

for i in {1..20}; do
  sleep 30
  PODS=$(kubectl get pods -l app=nginx 2>/dev/null | grep -c "Running")
  MIN=$((i/2))
  SEC=$(( (i%2)*30 ))
  echo "  $MIN minutes $SEC seconds: $PODS pods"
done

# Final state
echo -e "\nFinal State (should be min replicas):"
kubectl get hpa
kubectl get pods -l app=nginx

echo -e "\n=== Test Complete ==="
echo "HPA successfully scaled up under load and scaled down when idle."
```

## Quick Reference Commands:

```bash
# Deploy with scale down behavior
kubectl apply -f nginx-deployment.yml
kubectl apply -f nginx-service.yml
kubectl apply -f nginx-hpa-scale-down.yml

# Monitor scale down
watch -n 5 'kubectl get hpa -o=custom-columns=NAME:.metadata.name,CURRENT:.status.currentReplicas,DESIRED:.status.desiredReplicas,CPU:.status.currentCPUUtilizationPercentage'

# Force immediate scale (testing only)
kubectl scale deployment nginx-deployment --replicas=10
kubectl scale deployment nginx-deployment --replicas=2

# Check scale down events
kubectl describe hpa nginx-hpa | grep -i "scaledown\|stabilization"

# Modify scale down cooldown
kubectl patch hpa nginx-hpa --type=merge -p '{"spec":{"behavior":{"scaleDown":{"stabilizationWindowSeconds": 600}}}}'
```

**Key Points:**
1. HPA automatically scales down when CPU/Memory < 50%
2. Default 5-minute cooldown prevents rapid scale up/down cycles
3. Scale down removes pods gradually (not all at once)
4. Metrics Server must be running for HPA to work
5. Test with load patterns to verify scale down behavior