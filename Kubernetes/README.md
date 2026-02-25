# Kubernetes — Complete Learning Path 🚀

> **From "What's a container?" to "I can run production clusters confidently"**
>
> Written for someone with zero Kubernetes experience.
> Every concept uses real-world analogies, ASCII diagrams, and hands-on YAML examples.

---

## 🗺️ Learning Roadmap

```text
YOU ARE HERE
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 1 — FOUNDATIONS (Start here, no shortcuts!)              │
│                                                                 │
│  01. What Is Kubernetes?      ← Why it exists, real analogies   │
│  02. Architecture             ← How the pieces fit together     │
│  03. Pods                     ← The smallest unit you deploy    │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 2 — CORE WORKLOADS (You'll use these every day)         │
│                                                                 │
│  04. Workloads                ← Deployments, ReplicaSets, Jobs  │
│  05. Services & Networking    ← How traffic reaches your app    │
│  06. Storage                  ← Persistent data in containers   │
│  07. Configuration            ← ConfigMaps, Secrets, Env vars   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 3 — PRODUCTION READINESS (What separates dev from prod) │
│                                                                 │
│  08. RBAC & Security          ← Who can do what in your cluster │
│  09. Scaling                  ← Auto-scaling apps & clusters    │
│  10. Helm & Packaging         ← Package & share K8s apps        │
│  11. Monitoring & Logging     ← See what's happening inside     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 4 — MASTERY (Staff-level thinking)                      │
│                                                                 │
│  12. Production Best Practices ← Hardened, battle-tested setup  │
│  13. Troubleshooting           ← Debug like a pro               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Folder Structure

```text
Kubernetes/
├── README.md                          ← You are here
├── 01-what-is-kubernetes.md           ← Start here
├── 02-architecture.md
├── 03-pods.md
├── 04-workloads.md
├── 05-services-networking.md
├── 06-storage.md
├── 07-configuration.md
├── 08-rbac-security.md
├── 09-scaling.md
├── 10-helm-packaging.md
├── 11-monitoring-logging.md
├── 12-production-best-practices.md
├── 13-troubleshooting.md
└── examples/                          ← Copy-paste ready YAML files
    ├── pod.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── secret.yaml
    ├── pv-pvc.yaml
    ├── statefulset.yaml
    ├── hpa.yaml
    ├── rbac.yaml
    ├── networkpolicy.yaml
    ├── job.yaml
    └── helm-chart/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            └── service.yaml
```

---

## 🎯 How to Use This Guide

1. **Go in order** — each module builds on the previous one
2. **Read the diagrams** — they show you what the text explains
3. **Try the examples** — every YAML in `examples/` is ready to apply with `kubectl apply -f`
4. **Challenge yourself** — each module has a "Test Your Understanding" section
5. **Bookmark the troubleshooting guide** — you'll need it when things break (and they will!)

---

## 🛠️ Prerequisites

| Tool | What It Is | Install |
|------|-----------|---------|
| **Docker** | Runs containers on your machine | [docker.com](https://docs.docker.com/get-docker/) |
| **kubectl** | CLI to talk to Kubernetes | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| **minikube** | Runs a local K8s cluster for learning | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start/) |
| **Helm** (Level 3+) | Package manager for K8s | [helm.sh](https://helm.sh/docs/intro/install/) |

### Quick Setup (macOS)

```bash
# Install everything you need
brew install docker kubectl minikube helm

# Start your first cluster
minikube start

# Verify it works
kubectl cluster-info
kubectl get nodes
```

### Quick Setup (Linux)

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube-linux-amd64 && sudo mv minikube-linux-amd64 /usr/local/bin/minikube

# Start your cluster
minikube start

# Verify
kubectl cluster-info
```

---

## 🧭 Quick Reference — "Where Do I Find...?"

| I want to... | Go to |
|---|---|
| Understand why Kubernetes exists | `01-what-is-kubernetes.md` |
| See how the cluster is built | `02-architecture.md` |
| Deploy my first app | `03-pods.md` → `04-workloads.md` |
| Expose my app to the internet | `05-services-networking.md` |
| Store data that survives restarts | `06-storage.md` |
| Pass config/secrets to my app | `07-configuration.md` |
| Lock down who can do what | `08-rbac-security.md` |
| Handle traffic spikes automatically | `09-scaling.md` |
| Package my app for easy deployment | `10-helm-packaging.md` |
| Set up dashboards and alerts | `11-monitoring-logging.md` |
| Prepare for production | `12-production-best-practices.md` |
| Debug a broken pod/service | `13-troubleshooting.md` |
| Get copy-paste YAML files | `examples/` folder |
