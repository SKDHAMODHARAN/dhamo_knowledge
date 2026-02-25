# 05 — Services & Networking

## The Problem: Pod IPs Are Unreliable

```text
Remember: Pods are EPHEMERAL. They die and get recreated constantly.

  Before crash:
    Pod "web-abc" → IP: 10.244.1.5 ✅

  After crash (auto-recreated):
    Pod "web-xyz" → IP: 10.244.2.9 ← DIFFERENT IP!

  If your frontend was calling 10.244.1.5... it's now broken. 💀

  SOLUTION: Use a SERVICE — it's a stable address that never changes,
            even when Pods behind it come and go.
```

---

## What Is a Service?

```text
Think of it as: A PHONE NUMBER for a business

  You call Pizza Hut's main number → call center routes you to an available agent.
  
  You don't call individual employees' personal phones.
  Employees can quit/join — the main number never changes.

  ┌───────────────────────────────────────────────────┐
  │                  SERVICE                          │
  │          "web-service" (10.96.0.15)               │
  │                                                   │
  │    Stable IP ✅   Stable DNS name ✅               │
  │    Load balances across healthy Pods              │
  │                                                   │
  │         ┌──────────┬──────────┬──────────┐        │
  │         │  Pod 1   │  Pod 2   │  Pod 3   │        │
  │         │ 10.244.  │ 10.244.  │ 10.244.  │        │
  │         │ 1.5      │ 2.9      │ 1.12     │        │
  │         └──────────┴──────────┴──────────┘        │
  │                                                   │
  │    Pods change? Service IP stays the same.        │
  └───────────────────────────────────────────────────┘
```

---

## Service Types — The 4 Flavors

```text
┌─────────────────────────────────────────────────────────────────────┐
│                       SERVICE TYPES                                 │
│                                                                     │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────────┐  │
│  │  ClusterIP   │   │  NodePort    │   │    LoadBalancer        │  │
│  │  (default)   │   │             │   │                        │  │
│  │              │   │  Opens a    │   │  Cloud provider        │  │
│  │  Internal    │   │  port on    │   │  creates a real        │  │
│  │  only —      │   │  EVERY node │   │  load balancer         │  │
│  │  inside      │   │  (30000-    │   │  (AWS ALB/NLB,         │  │
│  │  cluster     │   │   32767)    │   │   GCP LB, Azure LB)   │  │
│  └──────────────┘   └──────────────┘   └────────────────────────┘  │
│                                                                     │
│  ┌────────────────────────────────────────────┐                     │
│  │  ExternalName                              │                     │
│  │  DNS alias to an external service          │                     │
│  │  (e.g., point to an RDS database)          │                     │
│  └────────────────────────────────────────────┘                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Comparison Table

| Type | Access From | Use Case | Example |
|------|------------|----------|---------|
| **ClusterIP** | Inside cluster only | Service-to-service communication | Frontend → Backend API |
| **NodePort** | Outside via node IP:port | Dev/testing, bare-metal clusters | Access app at `<NodeIP>:30080` |
| **LoadBalancer** | Internet via cloud LB | Production web apps | `https://myapp.com` |
| **ExternalName** | DNS alias | Point to external service | Map `my-db` to `rds.amazonaws.com` |

### Decision Tree

```text
Where do I need to access the service from?

├── Only from OTHER PODS inside the cluster?
│   └── ClusterIP ✅ (default, most secure)
│
├── From outside, but no cloud provider?
│   └── NodePort ✅ (opens port 30000-32767 on every node)
│
├── From the internet, on a cloud provider (AWS/GCP/Azure)?
│   └── LoadBalancer ✅ (creates real cloud LB)
│
└── Just need a DNS alias to an external service?
    └── ExternalName ✅
```

---

## ClusterIP Service (Default)

```text
  ┌──────────────────────────────────────────────────┐
  │                    CLUSTER                        │
  │                                                  │
  │  ┌──────────┐    ClusterIP     ┌──────────────┐ │
  │  │ Frontend │───→ 10.96.0.15 ──→│ Backend Pods │ │
  │  │ Pod      │    (stable!)     │ Pod 1, 2, 3  │ │
  │  └──────────┘                  └──────────────┘ │
  │                                                  │
  │  Frontend calls: http://backend-service:8080     │
  │  K8s DNS resolves "backend-service" → 10.96.0.15│
  │  kube-proxy routes to one of the backend Pods   │
  │                                                  │
  │  ❌ NOT accessible from outside the cluster      │
  └──────────────────────────────────────────────────┘
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP               # Default — can be omitted
  selector:
    app: backend                 # Route traffic to Pods with label app=backend
  ports:
    - port: 8080                 # Port the Service listens on
      targetPort: 8080           # Port the Pod container listens on
      protocol: TCP
```

### How the Selector Works

```text
  Service selector: app=backend

  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
  │ Pod 1          │  │ Pod 2          │  │ Pod 3          │
  │ labels:        │  │ labels:        │  │ labels:        │
  │   app: backend │  │   app: backend │  │   app: frontend│
  │   ✅ matches   │  │   ✅ matches   │  │   ❌ no match  │
  └───────────────┘  └───────────────┘  └───────────────┘

  Service routes traffic to Pod 1 and Pod 2 only.
```

---

## NodePort Service

```text
  ┌─────────────────────────────────────────────────────────────┐
  │                        CLUSTER                              │
  │                                                             │
  │   External User                                             │
  │   http://192.168.1.10:30080                                 │
  │        │                                                    │
  │        ▼                                                    │
  │   ┌──────────┐     ┌──────────┐     ┌──────────┐          │
  │   │  Node 1  │     │  Node 2  │     │  Node 3  │          │
  │   │ :30080   │     │ :30080   │     │ :30080   │          │
  │   └────┬─────┘     └────┬─────┘     └────┬─────┘          │
  │        │                │                │                  │
  │        └────────────────┼────────────────┘                  │
  │                         │                                   │
  │                    ┌────▼─────┐                             │
  │                    │ Service  │                             │
  │                    │ ClusterIP│                             │
  │                    └────┬─────┘                             │
  │              ┌──────────┼──────────┐                        │
  │              │          │          │                        │
  │         ┌────▼───┐ ┌───▼────┐ ┌───▼────┐                  │
  │         │ Pod 1  │ │ Pod 2  │ │ Pod 3  │                  │
  │         └────────┘ └────────┘ └────────┘                  │
  └─────────────────────────────────────────────────────────────┘

  Port 30080 is opened on ALL nodes (even nodes without the Pod).
  You can access it via ANY node's IP.
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
    - port: 80               # Service port (internal)
      targetPort: 8080        # Container port
      nodePort: 30080         # External port (30000-32767)
```

---

## LoadBalancer Service

```text
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │    Internet                                                  │
  │       │                                                      │
  │       ▼                                                      │
  │  ┌──────────────────────────────┐                            │
  │  │  Cloud Load Balancer         │                            │
  │  │  (AWS ALB / GCP LB / Azure)  │                            │
  │  │  External IP: 34.56.78.90    │                            │
  │  └──────────────┬───────────────┘                            │
  │                 │                                            │
  │       ┌─────────┼─────────┐                                  │
  │       │         │         │                                  │
  │   ┌───▼───┐ ┌───▼───┐ ┌───▼───┐                             │
  │   │Node 1 │ │Node 2 │ │Node 3 │                             │
  │   │:30080 │ │:30080 │ │:30080 │                             │
  │   └───┬───┘ └───┬───┘ └───┬───┘                             │
  │       └─────────┼─────────┘                                  │
  │            ┌────▼─────┐                                      │
  │            │ Service  │                                      │
  │            └────┬─────┘                                      │
  │         ┌───────┼───────┐                                    │
  │     ┌───▼──┐ ┌──▼───┐ ┌▼──────┐                             │
  │     │Pod 1 │ │Pod 2 │ │Pod 3  │                             │
  │     └──────┘ └──────┘ └───────┘                             │
  └──────────────────────────────────────────────────────────────┘
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-public
spec:
  type: LoadBalancer
  selector:
    app: web-app
  ports:
    - port: 80
      targetPort: 8080
```

```bash
# After applying, check the external IP
kubectl get svc web-public

# NAME         TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)
# web-public   LoadBalancer   10.96.0.20    34.56.78.90     80:31234/TCP
#                                           ▲
#                                      Access your app here!
```

**Cost warning:** Each LoadBalancer Service creates a cloud load balancer ($15-25/month on AWS). For multiple services, use **Ingress** instead.

---

## Ingress — The Smart Router

```text
Problem: You have 5 apps. 5 LoadBalancer Services = 5 cloud LBs = $$$
Solution: ONE Ingress = ONE LB that routes based on URL path or hostname

  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │   Internet                                                   │
  │      │                                                       │
  │      ▼                                                       │
  │  ┌───────────────────────────────────────────┐               │
  │  │          INGRESS CONTROLLER               │               │
  │  │       (ONE load balancer)                  │               │
  │  │                                           │               │
  │  │  myapp.com/api/*    → backend-service     │               │
  │  │  myapp.com/*        → frontend-service    │               │
  │  │  admin.myapp.com/*  → admin-service       │               │
  │  └─────────┬──────────────┬──────────┬───────┘               │
  │            │              │          │                        │
  │       ┌────▼────┐   ┌────▼────┐ ┌───▼─────┐                 │
  │       │Backend  │   │Frontend │ │Admin    │                  │
  │       │Service  │   │Service  │ │Service  │                  │
  │       │(Cluster │   │(Cluster │ │(Cluster │                  │
  │       │  IP)    │   │  IP)    │ │  IP)    │                  │
  │       └─────────┘   └─────────┘ └─────────┘                 │
  └──────────────────────────────────────────────────────────────┘
```

### Ingress Setup (Two Parts)

**Part 1: Install an Ingress Controller** (you need this first!)

```bash
# NGINX Ingress Controller (most popular)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.0/deploy/static/provider/cloud/deploy.yaml

# Verify it's running
kubectl get pods -n ingress-nginx
```

**Part 2: Create Ingress Rules**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-service
                port:
                  number: 8080

          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80

    - host: admin.myapp.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: admin-service
                port:
                  number: 80
```

### Ingress with TLS (HTTPS)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.com
      secretName: myapp-tls-cert
  rules:
    - host: myapp.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

---

## DNS Inside Kubernetes

```text
Every Service gets a DNS name automatically:

  <service-name>.<namespace>.svc.cluster.local

  Examples:
  ┌────────────────────────────────────────────────────────────┐
  │ Service Name    │ Namespace │ Full DNS Name                │
  │─────────────────┼───────────┼──────────────────────────────│
  │ backend-service │ default   │ backend-service.default.svc  │
  │                 │           │   .cluster.local             │
  │ redis           │ cache     │ redis.cache.svc.cluster.local│
  │ postgres        │ database  │ postgres.database.svc        │
  │                 │           │   .cluster.local             │
  └────────────────────────────────────────────────────────────┘

  Shortcuts (within same namespace):
    curl http://backend-service:8080     ← just the name works!
  
  Cross-namespace:
    curl http://redis.cache:6379         ← name.namespace
```

---

## NetworkPolicy — Firewall Rules for Pods

```text
By default, ALL Pods can talk to ALL other Pods.
NetworkPolicies restrict this — like firewall rules.

WITHOUT NetworkPolicy:
  ┌──────────┐     ┌──────────┐     ┌──────────┐
  │ Frontend │ ←──→│ Backend  │ ←──→│ Database │
  │          │ ←──→│          │     │          │
  │          │ ←────────────────────→│          │ ← 😱 Frontend
  └──────────┘     └──────────┘     └──────────┘    can talk
                                                      to DB directly!
WITH NetworkPolicy:
  ┌──────────┐     ┌──────────┐     ┌──────────┐
  │ Frontend │ ───→│ Backend  │ ───→│ Database │
  │          │     │          │     │          │
  │          │ ──✖─────────────────→│          │ ← 🔒 Blocked!
  └──────────┘     └──────────┘     └──────────┘
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-restrict
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: database           # Apply to database pods

  policyTypes:
    - Ingress                 # Control incoming traffic

  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: backend    # ONLY allow traffic from backend pods
      ports:
        - protocol: TCP
          port: 5432
```

### Default Deny All Traffic

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  podSelector: {}             # Apply to ALL pods in namespace
  policyTypes:
    - Ingress
    - Egress
```

**Production best practice:** Start with "deny all" and explicitly allow only what's needed (whitelist approach).

---

## Headless Service — For StatefulSets

```text
Normal Service:
  Client → Service IP (10.96.0.15) → random Pod

Headless Service (clusterIP: None):
  Client → DNS returns ALL Pod IPs directly
  Client talks to specific Pods by name:
    postgres-0.postgres-headless.default.svc.cluster.local
    postgres-1.postgres-headless.default.svc.cluster.local
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None            # ← This makes it headless
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```

Used with StatefulSets where each Pod needs a **stable, unique DNS name**.

---

## Port Terminology Cheat Sheet

```text
  External User
       │
       │  nodePort: 30080 (port on the physical node)
       ▼
  ┌─────────┐
  │  Node   │
  └────┬────┘
       │
       │  port: 80 (port on the Service's ClusterIP)
       ▼
  ┌─────────┐
  │ Service │
  └────┬────┘
       │
       │  targetPort: 8080 (port on the container)
       ▼
  ┌─────────┐
  │   Pod   │
  │  :8080  │
  └─────────┘
```

| Port Type | Where It Exists | Who Uses It |
|-----------|----------------|-------------|
| **containerPort** | Pod spec | Informational — what port the app listens on |
| **targetPort** | Service spec | Port traffic is forwarded TO on the Pod |
| **port** | Service spec | Port the Service listens on (ClusterIP) |
| **nodePort** | Service spec (NodePort type) | Port opened on every node (30000-32767) |

---

## Common kubectl Commands for Services

```bash
# List all services
kubectl get svc

# Describe a service (see endpoints/pod IPs)
kubectl describe svc backend-service

# Get Ingress resources
kubectl get ingress

# Describe Ingress (see rules and backend)
kubectl describe ingress app-ingress

# Test DNS resolution from inside a Pod
kubectl run -it --rm debug --image=busybox -- nslookup backend-service

# Get endpoints (which Pod IPs are behind a Service)
kubectl get endpoints backend-service

# Port-forward to access a ClusterIP service locally
kubectl port-forward svc/backend-service 8080:8080
# Now access http://localhost:8080
```

---

## Test Your Understanding 🧪

1. **Why can't you rely on Pod IPs for communication?**
2. **What's the difference between ClusterIP and LoadBalancer?**
3. **When would you use an Ingress instead of a LoadBalancer Service?**
4. **How does a Service find the right Pods to route traffic to?**
5. **What's a headless Service and when do you need one?**
6. **What's the default NetworkPolicy behavior (when none exists)?**

<details>
<summary>Click to see answers</summary>

1. Pod IPs change every time a Pod is recreated. Services provide a stable IP and DNS name that doesn't change, even when Pods behind it come and go.

2. **ClusterIP** is internal only — accessible only from within the cluster. **LoadBalancer** creates a real cloud load balancer with an external IP accessible from the internet.

3. When you have multiple services. Each LoadBalancer creates a cloud LB (costs $15-25/month). An Ingress uses ONE LB and routes traffic based on URL path or hostname — much cheaper and more flexible.

4. Using **label selectors**. The Service has a `selector` field (e.g., `app: backend`), and it routes traffic to all Pods that have that label.

5. A headless Service (`clusterIP: None`) returns individual Pod IPs via DNS instead of a single Service IP. Needed for StatefulSets where you need to address specific Pods by name (e.g., `postgres-0`, `postgres-1`).

6. When no NetworkPolicy exists, ALL Pods can communicate with ALL other Pods — fully open. That's why you should create "deny-all" policies and then whitelist allowed communication.

</details>

---

## What's Next?

➡️ **[06 — Storage](./06-storage.md)** — Persistent data in containers
