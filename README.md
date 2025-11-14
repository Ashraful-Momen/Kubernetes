

---

## 🔹 Kubernetes Structure (Concept)

Kubernetes (K8s) is a container orchestration system that manages:

* **Cluster of nodes (servers)**
* **Pods (groups of containers)**
* **Services (stable networking / load balancing)**
* **Controllers (Deployment, ReplicaSet, etc.)**
* **API Server (the “brain”)**

---

## 🔹 ASCII Diagram of Kubernetes Cluster

```
                   ┌───────────────────────────┐
                   │       Master Node         │
                   │───────────────────────────│
                   │  API Server  (Brain)      │
                   │  Scheduler   (Planner)    │
                   │  Controller  (Manager)    │
                   │  etcd (Database / Memory) │
                   └───────────┬──────────────┘
                               │
        ┌──────────────────────┼───────────────────────┐
        │                      │                       │
┌───────▼───────┐      ┌───────▼───────┐       ┌───────▼───────┐
│   Worker Node │      │   Worker Node │       │   Worker Node │
│───────────────│      │───────────────│       │───────────────│
│  Kubelet      │      │  Kubelet      │       │  Kubelet      │
│  Kube-proxy   │      │  Kube-proxy   │       │  Kube-proxy   │
│               │      │               │       │               │
│  ┌─────────┐  │      │  ┌─────────┐  │       │  ┌─────────┐  │
│  │   Pod   │  │      │  │   Pod   │  │       │  │   Pod   │  │
│  │ (apps)  │  │      │  │ (apps)  │  │       │  │ (apps)  │  │
│  └─────────┘  │      │  └─────────┘  │       │  └─────────┘  │
└───────────────┘      └───────────────┘       └───────────────┘
```

---

## 🔹 Real-Life Analogy 🏭

Think of Kubernetes like a **company factory**:

* **Master Node** = **Head Office (CEO + Managers)**

  * **API Server** → Receptionist taking all requests
  * **Scheduler** → HR assigning tasks to workers
  * **Controller Manager** → Supervisors checking work is correct
  * **etcd** → Company diary storing records

* **Worker Nodes** = **Factory Branches**

  * **Kubelet** → Floor Manager ensuring machines (containers) run
  * **Kube-proxy** → Security / Networking team directing traffic
  * **Pods** = **Machines or workers doing the actual job** (your apps like web server, database, etc.)

* **Service** = **Reception Desk in each branch** → Even if one worker is busy, clients still get served (load balancing).

---

👉 In short:

* **Master** = Brain & Manager
* **Workers** = Do the actual work (run containers)
* **Pods** = The actual apps
* **Service** = Ensures clients can always reach the apps

---

```
       ┌─────────────────────────────┐
       │          User               │
       │  runs kubectl command       │
       │  e.g., kubectl create pod   │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │       kubectl CLI           │
       │  Sends request to API       │
       │  Server (Master Node)       │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │      API Server             │
       │  Validates & processes      │
       │  request                    │
       │  e.g., kubectl get pods     │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │       Scheduler             │
       │ Chooses which Worker Node   │
       │ will run the Pod            │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │ Controller Manager           │
       │ Ensures desired state matches│
       │ actual state (deployments)   │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │ etcd (Cluster DB)           │
       │ Stores cluster state        │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │        Kubelet              │
       │ Worker Node receives        │
       │ instructions to run Pod     │
       │ e.g., kubectl describe node │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │       Kube-proxy            │
       │ Handles pod networking &    │
       │ load balancing              │
       └─────────────┬──────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │          Pod                 │
       │  Runs container(s)           │
       │  Your app is live here       │
       │  e.g., kubectl get pods      │
       └─────────────────────────────┘
```

---

### 🔹 **Flow Summary with Commands**

1. **kubectl CLI** → `kubectl create pod nginx`
2. **API Server** → Validates request
3. **Scheduler** → Chooses worker node
4. **Controller Manager** → Ensures state matches deployment
5. **etcd** → Stores cluster info
6. **Kubelet** → Runs pod on worker
7. **Kube-proxy** → Sets up networking & service
8. **Pod** → Container runs your app
9. **Check status** → `kubectl get pods -o wide`
