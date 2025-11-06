Perfect — great catch ✅

Here’s your **updated Kubernetes Learning Roadmap (Phase 1 → 5)** — now including **SonarQube integration** under production / CI-CD (Phase 5).
It’s tuned for someone who already knows Docker inside-out and wants to move toward real-world Kubernetes DevOps skills.

---

## 🧭 **Kubernetes Learning Roadmap — Phase 1 → 5 (with SonarQube)**

---

### 🟢 **Phase 1 — Core Kubernetes Basics (Local Playground)**

**Goal:** Understand the control plane, run your first app locally with Minikube.

**Learn**

* What Kubernetes is (Control Plane vs Worker Node, Pods)
* Install & set up:

  * `minikube`
  * `kubectl`
* Core resources: **Pod → ReplicaSet → Deployment → Service**
* Commands: `get | describe | logs | exec | apply | delete`
* Manual scaling:
  `kubectl scale deployment app --replicas=3`
* `minikube dashboard`

**Practice**

* Deploy NGINX
* Expose it via NodePort
* Visit with `minikube service nginx`

---

### 🟡 **Phase 2 — YAML Deep Dive & Deployment Management**

**Goal:** Define everything declaratively.

**Learn**

* YAML structure for Kubernetes objects
* Labels / selectors / annotations
* Rolling updates & rollbacks
* Namespaces
* Resource requests & limits
* Liveness vs Readiness probes

**Practice**

* Write your own `deployment.yaml`
* Update image → observe rolling update
* `kubectl rollout history` + `undo`
* Separate workloads by namespace

---

### 🟠 **Phase 3 — Networking & Storage**

**Goal:** Learn pod-to-pod comms and persistent data.

**Learn**

* Cluster network model & DNS service discovery
* Service types: ClusterIP / NodePort / LoadBalancer / Ingress
* Ingress Controller (NGINX Ingress)
* Volumes: EmptyDir, HostPath, PV, PVC, StorageClass

**Practice**

* Deploy backend + frontend
* Add Ingress routes `/api`, `/web`
* Attach PersistentVolume to store data

---

### 🔵 **Phase 4 — Scaling, Monitoring & Health**

**Goal:** Keep apps healthy and auto-scale them.

**Learn**

* Metrics Server (`minikube addons enable metrics-server`)
* `kubectl top pods/nodes`
* HPA + VPA
* Resource quotas
* Deep dive into probes
* Logs, events, troubleshooting (`describe`, `logs`)

**Practice**

* Set CPU/memory requests
* Create HPA → simulate load → watch auto-scaling
* Crash a pod → see auto-healing

---

### 🔴 **Phase 5 — Advanced / Production Concepts (+ SonarQube & CI/CD)**

**Goal:** Move beyond local → secure, observable production clusters.

**Learn**

1. **Cluster setup with kubeadm**

   * Control plane / worker join
   * CNI plugins (Calico, Flannel)

2. **RBAC (roles, bindings, service accounts)**
   Secure cluster access

3. **Helm (package manager)**
   Deploy Prometheus, Grafana, NGINX Ingress, SonarQube

4. **Secrets management**
   `kubectl create secret`, sealed-secrets

5. **CI/CD pipelines with GitHub Actions**
   Build → SonarQube Code Analysis → Push → Deploy to Cluster

6. **SonarQube integration**

   * Deploy SonarQube on Kubernetes via Helm chart
   * Use GitHub Action to analyze code and send reports to SonarQube
   * Visualize code quality metrics in the SonarQube UI

7. **Monitoring & Logging**

   * Prometheus + Grafana + Loki for metrics & logs

8. **Deployment strategies**

   * Rolling / Blue-Green / Canary

9. **Node & storage management**

   * Taints, tolerations, affinities
   * AWS EBS / NFS / Local PV

**Practice**

* Build your own multi-node cluster (kubeadm or cloud)
* Deploy SonarQube via Helm
* Integrate SonarQube in GitHub Action pipeline
* Add RBAC rules & monitor with Grafana

---

### 🧩 **Helpful Tools**

| Tool                            | Use                              |
| ------------------------------- | -------------------------------- |
| **k9s**                         | Terminal UI                      |
| **Lens**                        | GUI cluster manager              |
| **Helm**                        | App packaging & deployment       |
| **Prometheus / Grafana / Loki** | Observability stack              |
| **ArgoCD / Flux**               | GitOps deployment                |
| **SonarQube**                   | Code Quality & Security analysis |

---

### ⚙️ **Summary**

| Phase | Focus                | Key Skills                     |
| ----- | -------------------- | ------------------------------ |
| 1     | Core Basics          | Pods, Deployments, Services    |
| 2     | YAML & Rollouts      | Declarative configs, rollbacks |
| 3     | Networking & Storage | Ingress, PV/PVC                |
| 4     | Scaling & Monitoring | HPA, metrics, probes           |
| 5     | Prod & CI/CD         | Helm, kubeadm, RBAC, SonarQube |

---

Would you like me to now turn this into a **day-by-day (2-week)** hands-on plan — with YAML examples, kubectl commands, and SonarQube CI/CD tasks using Minikube on your Kali Linux?
