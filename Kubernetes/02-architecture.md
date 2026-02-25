# 02 — Kubernetes Architecture

## The Big Picture

Think of Kubernetes like an **airline company**:

```text
┌──────────────────────────────────────────────────────────────────────┐
│                        AIRLINE COMPANY = CLUSTER                     │
│                                                                      │
│  ┌────────────────────────────┐    ┌──────────────────────────────┐  │
│  │    CONTROL TOWER (HQ)      │    │         AIRPLANES            │  │
│  │    = Control Plane         │    │         = Worker Nodes        │  │
│  │                            │    │                              │  │
│  │  • Decides which plane     │    │  • Actually carry the        │  │
│  │    goes where              │    │    passengers (your apps)    │  │
│  │  • Monitors all flights    │    │  • Report status back to HQ │  │
│  │  • Reschedules if a plane  │    │  • Follow instructions      │  │
│  │    has problems            │    │    from control tower        │  │
│  │  • Stores all flight data  │    │                              │  │
│  └────────────────────────────┘    └──────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

A Kubernetes cluster has **two main parts**:
1. **Control Plane** — the brain (makes decisions)
2. **Worker Nodes** — the muscles (run your apps)

---

## Complete Architecture Diagram

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                          KUBERNETES CLUSTER                                │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      CONTROL PLANE (Master)                          │  │
│  │                                                                      │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────────┐ │  │
│  │  │  API Server   │  │  Scheduler   │  │  Controller Manager        │ │  │
│  │  │              │  │              │  │                            │ │  │
│  │  │ Front door   │  │ Decides which│  │ Watches & fixes things:   │ │  │
│  │  │ for ALL      │  │ node runs    │  │ • ReplicaSet controller   │ │  │
│  │  │ communication│  │ each pod     │  │ • Deployment controller   │ │  │
│  │  │              │  │              │  │ • Node controller         │ │  │
│  │  │ Port: 6443   │  │              │  │ • Job controller          │ │  │
│  │  └──────┬───────┘  └──────────────┘  └────────────────────────────┘ │  │
│  │         │                                                            │  │
│  │  ┌──────▼───────┐  ┌───────────────────────────────────────────────┐ │  │
│  │  │    etcd       │  │  Cloud Controller Manager (optional)         │ │  │
│  │  │              │  │  Talks to AWS/GCP/Azure for load balancers,  │ │  │
│  │  │ The database │  │  storage, and node management                │ │  │
│  │  │ (key-value)  │  └───────────────────────────────────────────────┘ │  │
│  │  │ Stores ALL   │                                                    │  │
│  │  │ cluster state│                                                    │  │
│  │  └──────────────┘                                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                       │
│                          kubectl / API calls                               │
│                                    │                                       │
│  ┌─────────────────────────────────▼────────────────────────────────────┐  │
│  │                        WORKER NODES                                  │  │
│  │                                                                      │  │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────────┐   │  │
│  │  │         NODE 1              │  │         NODE 2              │   │  │
│  │  │                             │  │                             │   │  │
│  │  │  ┌────────┐ ┌────────┐     │  │  ┌────────┐                │   │  │
│  │  │  │ Pod A  │ │ Pod B  │     │  │  │ Pod C  │                │   │  │
│  │  │  └────────┘ └────────┘     │  │  └────────┘                │   │  │
│  │  │                             │  │                             │   │  │
│  │  │  ┌─────────────────────┐   │  │  ┌─────────────────────┐   │   │  │
│  │  │  │ kubelet             │   │  │  │ kubelet             │   │   │  │
│  │  │  │ (Node agent)        │   │  │  │ (Node agent)        │   │   │  │
│  │  │  └─────────────────────┘   │  │  └─────────────────────┘   │   │  │
│  │  │  ┌─────────────────────┐   │  │  ┌─────────────────────┐   │   │  │
│  │  │  │ kube-proxy          │   │  │  │ kube-proxy          │   │   │  │
│  │  │  │ (Network rules)     │   │  │  │ (Network rules)     │   │   │  │
│  │  │  └─────────────────────┘   │  │  └─────────────────────┘   │   │  │
│  │  │  ┌─────────────────────┐   │  │  ┌─────────────────────┐   │   │  │
│  │  │  │ Container Runtime   │   │  │  │ Container Runtime   │   │   │  │
│  │  │  │ (containerd/CRI-O)  │   │  │  │ (containerd/CRI-O)  │   │   │  │
│  │  │  └─────────────────────┘   │  │  └─────────────────────┘   │   │  │
│  │  └─────────────────────────────┘  └─────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Control Plane Components (The Brain)

### 1. API Server (`kube-apiserver`)

```text
Think of it as: The RECEPTION DESK of a hospital

  Doctor (kubectl)  ──→  Reception (API Server)  ──→  Hospital systems
  Patient (Pod)     ──→  Reception (API Server)  ──→  Assign room
  Nurse (kubelet)   ──→  Reception (API Server)  ──→  Report status

EVERYTHING goes through reception. No one talks directly to each other.
```

| What It Does | Details |
|---|---|
| **Single entry point** | Every request (from kubectl, nodes, controllers) goes through the API Server |
| **Authentication** | Checks WHO you are (certificates, tokens) |
| **Authorization** | Checks WHAT you're allowed to do (RBAC) |
| **Validation** | Checks if your request makes sense (valid YAML?) |
| **Persists state** | Writes everything to etcd |

**Key point:** The API Server is **stateless**. It doesn't store anything itself — it reads/writes to etcd.

### 2. etcd

```text
Think of it as: The FILING CABINET where the hospital stores every patient record

  ┌──────────────────────────────────────────────────┐
  │                     etcd                          │
  │                                                  │
  │  Key                    │  Value                  │
  │  ───────────────────────┼────────────────────────│
  │  /pods/nginx-abc123     │  {status: Running...}  │
  │  /deployments/web       │  {replicas: 3...}      │
  │  /services/frontend     │  {port: 80...}         │
  │  /nodes/worker-1        │  {ready: true...}      │
  │  /secrets/db-password   │  {encoded: base64...}  │
  └──────────────────────────────────────────────────┘
```

| What It Does | Details |
|---|---|
| **Stores ALL cluster state** | Every Pod, Service, Deployment, Secret — everything is in etcd |
| **Key-value database** | Simple storage: key → value |
| **Distributed** | Runs on multiple machines for reliability |
| **Source of truth** | If it's not in etcd, Kubernetes doesn't know about it |

**Critical production rule:** Always back up etcd. Losing etcd = losing your entire cluster state.

### 3. Scheduler (`kube-scheduler`)

```text
Think of it as: A WEDDING PLANNER assigning guests to tables

  "Table 1 has space, Table 2 is full, Guest X needs wheelchair access..."

  The Scheduler decides WHICH NODE runs each new Pod:

  New Pod needs:
    - 500m CPU
    - 256Mi memory
    - GPU: yes
    - Zone: us-east-1a

  Scheduler checks:
    Node 1: 2000m CPU free, 4Gi memory, NO GPU     → ❌ No GPU
    Node 2: 100m CPU free, 128Mi memory, has GPU    → ❌ Not enough resources
    Node 3: 1000m CPU free, 2Gi memory, has GPU     → ✅ Perfect match!

  Result: Pod → Node 3
```

| Factor | What It Checks |
|--------|---------------|
| **Resource requests** | Does the node have enough CPU/memory? |
| **Node selectors** | Does the Pod require specific node labels? |
| **Taints & tolerations** | Is the node reserved for specific workloads? |
| **Affinity rules** | Should this Pod be near/far from other Pods? |
| **Available ports** | Does the node have the required ports free? |

### 4. Controller Manager (`kube-controller-manager`)

```text
Think of it as: A team of QUALITY INSPECTORS in a factory

Each inspector watches ONE thing and fixes it if it's wrong:

  ┌──────────────────────────────────────────────────────────┐
  │                  Controller Manager                       │
  │                                                          │
  │  ┌─────────────────────┐  ┌─────────────────────┐       │
  │  │ ReplicaSet Controller│  │ Node Controller     │       │
  │  │                     │  │                     │       │
  │  │ "You said 3 pods,   │  │ "Node 2 stopped    │       │
  │  │  I see 2. Let me    │  │  responding. Mark   │       │
  │  │  create 1 more."    │  │  it as NotReady."   │       │
  │  └─────────────────────┘  └─────────────────────┘       │
  │                                                          │
  │  ┌─────────────────────┐  ┌─────────────────────┐       │
  │  │ Deployment Controller│  │ Job Controller      │       │
  │  │                     │  │                     │       │
  │  │ "New version? Let   │  │ "Run this task once │       │
  │  │  me do a rolling    │  │  and mark it done." │       │
  │  │  update."           │  │                     │       │
  │  └─────────────────────┘  └─────────────────────┘       │
  │                                                          │
  │  ┌─────────────────────┐  ┌─────────────────────┐       │
  │  │ Service Controller  │  │ Endpoint Controller  │       │
  │  │                     │  │                     │       │
  │  │ "Cloud LB needed.   │  │ "Update the list of │       │
  │  │  Let me create it." │  │  Pod IPs behind this│       │
  │  │                     │  │  Service."          │       │
  │  └─────────────────────┘  └─────────────────────┘       │
  └──────────────────────────────────────────────────────────┘
```

**The key concept:** Every controller runs a **reconciliation loop**:

```text
  ┌───────────────────────────────────────────────────┐
  │                                                   │
  │   ┌──────────┐     Compare      ┌──────────┐     │
  │   │ DESIRED  │ ──────────────→  │ ACTUAL   │     │
  │   │ STATE    │                  │ STATE    │     │
  │   │          │                  │          │     │
  │   │ "I want  │     Different?   │ "I have  │     │
  │   │  3 pods" │     Take action! │  2 pods" │     │
  │   └──────────┘                  └──────────┘     │
  │        ▲                             │            │
  │        │         Reconcile           │            │
  │        └─────────────────────────────┘            │
  │              (Create 1 more pod)                  │
  │                                                   │
  │   This loop runs FOREVER, every few seconds.      │
  └───────────────────────────────────────────────────┘
```

This is the **most important concept in Kubernetes**: You tell it the **desired state**, and it continuously works to make **actual state = desired state**.

---

## Worker Node Components (The Muscles)

### 1. kubelet

```text
Think of it as: A SITE MANAGER at a construction site

  Control Plane says: "Build 3 houses on this lot"
  kubelet (Site Manager):
    ✅ Starts building (pulls container images, creates containers)
    ✅ Checks every 10 seconds: "Are the houses still standing?"
    ✅ Reports back: "All 3 houses are up and running"
    ✅ If a house falls → rebuilds it immediately
```

| What It Does | Details |
|---|---|
| **Runs on every node** | One kubelet per worker node |
| **Manages Pods** | Creates, starts, stops, and monitors containers |
| **Health checks** | Runs liveness/readiness probes |
| **Reports status** | Tells the API Server: "I'm healthy, here's what's running" |
| **Pulls images** | Downloads container images from registries |

### 2. kube-proxy

```text
Think of it as: A TELEPHONE SWITCHBOARD OPERATOR

  Incoming call → "I want to talk to the 'web' service"
  kube-proxy   → "Let me route you to one of the 3 web servers"

  It maintains network rules so that when you say
  "connect to service X", traffic reaches the right Pod.
```

| What It Does | Details |
|---|---|
| **Runs on every node** | Maintains network rules |
| **Load balancing** | Distributes traffic across Pods |
| **Service networking** | Makes Services work (maps Service IP → Pod IPs) |
| **Uses iptables/IPVS** | Configures Linux networking under the hood |

### 3. Container Runtime

```text
Think of it as: The ACTUAL CONSTRUCTION EQUIPMENT

  kubelet (manager) says: "Build this container"
  Container Runtime (bulldozer): *actually builds and runs it*
```

| Runtime | Notes |
|---------|-------|
| **containerd** | Most common, lightweight, production standard |
| **CRI-O** | Alternative, built specifically for Kubernetes |
| ~~Docker~~ | Removed in K8s 1.24 (Docker images still work, the runtime was replaced) |

---

## How Everything Talks to Each Other

```text
  kubectl apply -f deployment.yaml
        │
        ▼
  ┌─────────────┐      ┌─────────────┐
  │  API Server  │ ───→ │    etcd     │   (1) Store desired state
  └──────┬──────┘      └─────────────┘
         │
         │  (2) Notify
         ▼
  ┌──────────────┐
  │  Controller   │   (3) "Oh, 3 replicas needed, 0 exist. Create 3 Pods"
  │  Manager      │
  └──────┬───────┘
         │
         │  (4) New Pod objects created (in etcd, no node assigned yet)
         ▼
  ┌──────────────┐
  │  Scheduler    │   (5) "Pod A → Node 1, Pod B → Node 2, Pod C → Node 1"
  └──────┬───────┘
         │
         │  (6) Updates Pod objects with node assignments
         ▼
  ┌──────────────┐
  │  kubelet      │   (7) "I see I'm assigned Pod A. Let me pull the image
  │  (on Node 1)  │        and start the container."
  └──────┬───────┘
         │
         │  (8) Container starts running
         ▼
  ┌──────────────┐
  │  kube-proxy   │   (9) "New Pod is running. Let me update network rules
  │  (on Node 1)  │        so traffic can reach it."
  └──────────────┘
```

---

## Declarative vs. Imperative — A Critical Concept

Kubernetes is **declarative** (not imperative). This is a fundamental shift in thinking:

```text
IMPERATIVE (Traditional — telling the system WHAT TO DO step by step):
  "Create a server. Install nginx. Open port 80. Start nginx. 
   If it crashes, SSH in and restart it."

DECLARATIVE (Kubernetes — telling the system WHAT YOU WANT):
  "I want 3 nginx pods running on port 80."
  
  Kubernetes figures out HOW to make it happen and KEEPS it that way.
```

| Approach | Command | Thinking Style |
|----------|---------|---------------|
| **Imperative** | `kubectl run nginx --image=nginx` | "Do this now" |
| **Declarative** | `kubectl apply -f nginx.yaml` | "Make reality match this file" |

**Always use declarative (YAML files)** in production. Why?
- YAML files can be version-controlled (Git)
- They're reviewable in pull requests
- They're repeatable and predictable
- They document what your cluster should look like

---

## Control Plane: Single vs. High Availability

```text
DEVELOPMENT (Single Control Plane — OK for learning):

  ┌──────────────┐
  │ Control Plane│ ← Single point of failure!
  └──────┬───────┘
         │
    ┌────┴────┐
    │         │
  Node 1   Node 2


PRODUCTION (HA Control Plane — Required!):

  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │ Control Plane│  │ Control Plane│  │ Control Plane│
  │  (Primary)   │  │  (Standby)   │  │  (Standby)   │
  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
         │                 │                 │
         └────────┬────────┴────────┬────────┘
                  │                 │
              ┌───┴───┐        ┌───┴───┐
              │Node 1 │        │Node 2 │
              └───────┘        └───────┘

  • 3 or 5 etcd instances (odd number for consensus)
  • Load balancer in front of API Servers
  • If one control plane dies → others take over
```

---

## Cluster Types: Where Does K8s Run?

| Type | Where | Best For | Examples |
|------|-------|----------|---------|
| **Local** | Your laptop | Learning, development | Minikube, Kind, k3d, Docker Desktop |
| **Managed** | Cloud provider | Production (recommended) | EKS (AWS), GKE (Google), AKS (Azure) |
| **Self-managed** | Your own servers | Full control, compliance | kubeadm, Rancher, OpenShift |

### Why Managed Kubernetes is Almost Always Better for Production

```text
Self-managed:
  You handle: Control plane setup, etcd backups, upgrades, certificates,
              networking, security patches, monitoring, node provisioning...
  ❌ Takes a dedicated team

Managed (EKS/GKE/AKS):
  Cloud handles: Control plane, etcd, upgrades, certificates, HA
  You handle: Worker nodes, your apps, security policies
  ✅ Focus on your app, not infrastructure
```

---

## Namespaces — Organizing Your Cluster

```text
Think of it as: DEPARTMENTS in a company

  ┌─────────────────────────────────────────────────┐
  │                  CLUSTER                         │
  │                                                 │
  │  ┌─────────────────┐  ┌──────────────────────┐ │
  │  │  namespace:      │  │  namespace:           │ │
  │  │  development     │  │  production           │ │
  │  │                  │  │                       │ │
  │  │  - web app (v2)  │  │  - web app (v1)       │ │
  │  │  - test database │  │  - prod database      │ │
  │  │  - debug tools   │  │  - monitoring         │ │
  │  └─────────────────┘  └──────────────────────┘ │
  │                                                 │
  │  ┌─────────────────┐  ┌──────────────────────┐ │
  │  │  namespace:      │  │  namespace:           │ │
  │  │  kube-system     │  │  monitoring           │ │
  │  │  (K8s internals) │  │                       │ │
  │  │                  │  │  - prometheus          │ │
  │  │  - CoreDNS       │  │  - grafana             │ │
  │  │  - kube-proxy    │  │  - alertmanager        │ │
  │  └─────────────────┘  └──────────────────────┘ │
  └─────────────────────────────────────────────────┘
```

Default namespaces:

| Namespace | Purpose |
|-----------|---------|
| `default` | Where your stuff goes if you don't specify |
| `kube-system` | Kubernetes internal components |
| `kube-public` | Publicly accessible data (rarely used) |
| `kube-node-lease` | Node heartbeat tracking |

```bash
# List namespaces
kubectl get namespaces

# Create a namespace
kubectl create namespace staging

# List pods in a specific namespace
kubectl get pods -n staging

# List pods across ALL namespaces
kubectl get pods --all-namespaces
```

---

## Test Your Understanding 🧪

1. **What are the two main parts of a Kubernetes cluster?**
2. **What happens if etcd data is lost?**
3. **What's the difference between the Scheduler and the Controller Manager?**
4. **Why should you use YAML files instead of `kubectl run` commands in production?**
5. **Name the three components that run on every Worker Node.**
6. **Explain the reconciliation loop in your own words.**

<details>
<summary>Click to see answers</summary>

1. Control Plane (brain — API Server, etcd, Scheduler, Controller Manager) and Worker Nodes (muscles — kubelet, kube-proxy, container runtime).

2. You lose ALL cluster state. K8s won't know about any Pods, Services, Deployments, or Secrets. This is catastrophic — always back up etcd.

3. **Scheduler** decides WHERE (which node) a Pod runs. **Controller Manager** watches if the desired state matches actual state and takes action (creates/deletes Pods, manages Deployments, etc.).

4. YAML files are version-controlled (Git), reviewable (PRs), repeatable, and document what your cluster should look like. Imperative commands are fire-and-forget — no audit trail.

5. kubelet, kube-proxy, and container runtime (containerd/CRI-O).

6. "Kubernetes constantly compares what you ASKED for (desired state) with what ACTUALLY exists (current state). If they don't match, it takes action to fix it. This loop runs forever."

</details>

---

## What's Next?

➡️ **[03 — Pods](./03-pods.md)** — The smallest unit you deploy in Kubernetes
