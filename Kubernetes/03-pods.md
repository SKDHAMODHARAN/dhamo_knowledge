# 03 — Pods

## What Is a Pod?

A **Pod** is the **smallest thing you can deploy** in Kubernetes. It's a wrapper around one or more containers.

```text
Think of it as: A DORM ROOM in a university

  ┌──────────────────────────────┐
  │          POD                 │
  │   (Dorm Room)               │
  │                              │
  │   ┌──────────────────────┐  │
  │   │    Container          │  │
  │   │    (Student)          │  │
  │   │                      │  │
  │   │   Your app lives     │  │
  │   │   here               │  │
  │   └──────────────────────┘  │
  │                              │
  │   Shared:                    │
  │   • IP address (room number) │
  │   • Storage (shared closet)  │
  │   • Network (shared WiFi)    │
  └──────────────────────────────┘

  Most rooms have ONE student (one container per pod).
  Sometimes two students share a room (sidecar pattern).
  They share everything in the room, but each has their own bed.
```

### Key Rules About Pods

| Rule | Why |
|------|-----|
| **Most Pods have 1 container** | Keep it simple — one app per Pod |
| **Pods are ephemeral** (temporary) | They can be killed and recreated at any time |
| **Pods get a unique IP** | Every Pod gets its own IP address |
| **Don't create Pods directly** | Use Deployments (they manage Pods for you) |
| **Pods are NOT VMs** | They're lightweight — start in seconds |

---

## Pod Lifecycle

```text
┌─────────────────────────────────────────────────────────────┐
│                     POD LIFECYCLE                            │
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌─────────┐ │
│  │ Pending  │──→│ Running  │──→│Succeeded │   │ Failed  │ │
│  │          │   │          │──→│(completed)│   │         │ │
│  │ Waiting  │   │ All      │   └──────────┘   │ One or  │ │
│  │ to be    │   │ containers│                  │ more    │ │
│  │ scheduled│   │ are up   │──────────────────→│crashed  │ │
│  └──────────┘   └──────────┘                   └─────────┘ │
│                                                             │
│  Phases:                                                    │
│  • Pending  → Pod accepted, waiting for scheduling/download │
│  • Running  → At least one container is running             │
│  • Succeeded→ All containers exited with code 0             │
│  • Failed   → At least one container exited with error      │
│  • Unknown  → Can't talk to the node (network issue)        │
└─────────────────────────────────────────────────────────────┘
```

---

## Your First Pod — Step by Step

### The YAML File

```yaml
# examples/pod.yaml
apiVersion: v1              # Which K8s API version to use
kind: Pod                   # What are we creating? A Pod.
metadata:
  name: my-first-pod        # Name of the Pod (must be unique in namespace)
  labels:                   # Tags for organizing and selecting
    app: webserver
    environment: learning
spec:                       # The specification — what goes INSIDE the Pod
  containers:
    - name: nginx           # Name of the container
      image: nginx:1.25     # Docker image to run
      ports:
        - containerPort: 80 # Port the container listens on
```

### Breaking Down Every Line

```text
apiVersion: v1
│
├── "v1" = core/stable API (Pods, Services, ConfigMaps)
├── "apps/v1" = Deployments, StatefulSets, DaemonSets
└── "batch/v1" = Jobs, CronJobs

kind: Pod
│
└── The TYPE of Kubernetes object (Pod, Deployment, Service, etc.)

metadata:
│
├── name: "my-first-pod"  → Unique identifier
└── labels: → Key-value tags used for selection and organization
     ├── app: "webserver"       → Which app is this?
     └── environment: "learning" → What environment?

spec:
│
└── containers:  → List of containers in this Pod
     └── - name: "nginx"
         ├── image: "nginx:1.25"      → FROM Docker Hub
         └── ports:
              └── containerPort: 80    → App listens on port 80
```

### Run It

```bash
# Create the pod
kubectl apply -f pod.yaml

# Check status
kubectl get pods

# OUTPUT:
# NAME           READY   STATUS    RESTARTS   AGE
# my-first-pod   1/1     Running   0          30s

# Get detailed info
kubectl describe pod my-first-pod

# See the logs (what nginx is printing)
kubectl logs my-first-pod

# Execute a command inside the container
kubectl exec -it my-first-pod -- /bin/bash

# Delete the pod
kubectl delete pod my-first-pod
```

---

## Pod With Resource Limits (Production Must-Have!)

**Never deploy without resource limits.** Here's why:

```text
WITHOUT limits:
  ┌──────────────────────────────────────┐
  │              NODE (8 GB RAM)         │
  │                                      │
  │  ┌──────────┐  ┌──────────────────┐ │
  │  │ Pod A     │  │ Pod B (memory    │ │
  │  │ (1 GB)   │  │ leak!) 7 GB...   │ │
  │  │           │  │ 8 GB... BOOM!    │ │
  │  │  😵 killed│  │                  │ │
  │  └──────────┘  └──────────────────┘ │
  │                                      │
  │  Pod B consumed ALL memory.          │
  │  Pod A was killed. Node might crash. │
  └──────────────────────────────────────┘

WITH limits:
  ┌──────────────────────────────────────┐
  │              NODE (8 GB RAM)         │
  │                                      │
  │  ┌──────────┐  ┌──────────────────┐ │
  │  │ Pod A     │  │ Pod B            │ │
  │  │ limit:    │  │ limit: 2 GB      │ │
  │  │ 1 GB ✅  │  │ Tries to use 3GB │ │
  │  │           │  │ → K8s kills IT,  │ │
  │  │  safe!    │  │   not Pod A ✅   │ │
  │  └──────────┘  └──────────────────┘ │
  └──────────────────────────────────────┘
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
    - name: app
      image: nginx:1.25
      resources:
        requests:                # MINIMUM guaranteed resources
          cpu: "250m"            # 250 millicores = 0.25 CPU
          memory: "128Mi"        # 128 Mebibytes
        limits:                  # MAXIMUM allowed resources
          cpu: "500m"            # 500 millicores = 0.5 CPU
          memory: "256Mi"        # 256 Mebibytes
```

### Understanding CPU and Memory Units

```text
CPU:
  1 CPU = 1000m (millicores)
  "250m" = 0.25 CPU = 25% of one core
  "1"    = 1 full CPU core
  "2"    = 2 CPU cores

Memory:
  "128Mi" = 128 Mebibytes ≈ 134 MB
  "1Gi"   = 1 Gibibyte ≈ 1.07 GB
  "512Mi" = 512 Mebibytes ≈ 537 MB

Requests vs. Limits:
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  Request = "I need AT LEAST this much"               │
  │            (Used by Scheduler to pick a node)        │
  │                                                      │
  │  Limit   = "I can use AT MOST this much"             │
  │            (Enforced at runtime — K8s kills if        │
  │             you exceed memory limit)                  │
  │                                                      │
  │  ⚠️ CPU limit exceeded  → throttled (slowed down)    │
  │  ⚠️ Memory limit exceeded → OOMKilled (container     │
  │                              is killed and restarted) │
  └──────────────────────────────────────────────────────┘
```

---

## Health Checks — Liveness, Readiness, Startup Probes

```text
Think of it as: A DOCTOR checking on patients

  Liveness Probe  → "Is the patient ALIVE?"
                     If no → restart the container

  Readiness Probe → "Can the patient SEE VISITORS?"
                     If no → stop sending traffic to it

  Startup Probe   → "Has the patient WOKEN UP from surgery?"
                     If no → give it more time before checking
```

### Why All Three Matter

```text
WITHOUT health checks:
  User → Service → Pod (crashed, returning 500 errors)
  User sees: "Internal Server Error" 😡

WITH health checks:
  User → Service → Pod (crashed, REMOVED from Service)
                 → Pod (healthy, serving traffic) ✅
  User sees: Normal response 😊
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: health-check-demo
spec:
  containers:
    - name: app
      image: my-app:1.0
      ports:
        - containerPort: 8080

      # Is the container alive? If not, RESTART it.
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080
        initialDelaySeconds: 15    # Wait 15s after start before checking
        periodSeconds: 10          # Check every 10 seconds
        failureThreshold: 3        # 3 failures = restart

      # Is the container ready to receive traffic?
      readinessProbe:
        httpGet:
          path: /ready
          port: 8080
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 3        # 3 failures = stop sending traffic

      # For slow-starting apps: give it time to boot
      startupProbe:
        httpGet:
          path: /healthz
          port: 8080
        failureThreshold: 30       # Try 30 times...
        periodSeconds: 10          # ...every 10s = 5 minutes to start
```

### Probe Types

| Type | How It Works | Best For |
|------|-------------|----------|
| **httpGet** | Sends HTTP GET to a path | Web apps with health endpoints |
| **tcpSocket** | Tries to open a TCP connection | Databases, services without HTTP |
| **exec** | Runs a command inside the container | Custom health check scripts |

```yaml
# TCP probe example (for a database)
livenessProbe:
  tcpSocket:
    port: 5432
  periodSeconds: 10

# Command probe example
livenessProbe:
  exec:
    command:
      - cat
      - /tmp/healthy
  periodSeconds: 10
```

---

## Multi-Container Pods (Sidecar Pattern)

Most Pods have **one container**. But sometimes you need a helper:

```text
  ┌─────────────────────────────────────────────┐
  │                    POD                       │
  │                                             │
  │  ┌─────────────────┐  ┌─────────────────┐  │
  │  │  Main Container │  │ Sidecar Container│  │
  │  │  (Your app)     │  │ (Helper)         │  │
  │  │                 │  │                  │  │
  │  │  - Serves web   │  │  - Collects logs │  │
  │  │    pages        │  │  - Ships to      │  │
  │  │                 │  │    Elasticsearch  │  │
  │  └─────────────────┘  └─────────────────┘  │
  │                                             │
  │  Shared:                                    │
  │  ├── Same IP address (localhost)            │
  │  ├── Same volumes (shared files)            │
  │  └── Same network namespace                 │
  └─────────────────────────────────────────────┘
```

### Common Multi-Container Patterns

| Pattern | What It Does | Example |
|---------|-------------|---------|
| **Sidecar** | Adds functionality to the main container | Log shipper, service mesh proxy (Envoy/Istio) |
| **Ambassador** | Proxy that simplifies external connections | Local proxy to a remote database |
| **Init Container** | Runs BEFORE the main container starts | Wait for database, download config files |

### Init Container Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  # Init containers run FIRST, in order, one at a time
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command: ['sh', '-c', 'until nc -z database-service 5432; do echo "Waiting for DB..."; sleep 2; done']

  # Main container starts ONLY after all init containers succeed
  containers:
    - name: app
      image: my-app:1.0
      ports:
        - containerPort: 8080
```

```text
Timeline:
  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
  │ Init: wait   │ ──→ │ Init: done!  │ ──→ │ Main: app    │
  │ for DB...    │     │ DB is ready  │     │ starts       │
  │ (retrying)   │     │              │     │ running      │
  └──────────────┘     └──────────────┘     └──────────────┘
       10 sec               0 sec              forever
```

### Sidecar Example (Log Collector)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-demo
spec:
  volumes:
    - name: shared-logs
      emptyDir: {}

  containers:
    - name: app
      image: my-app:1.0
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/app

    - name: log-shipper
      image: fluentd:latest
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/app
          readOnly: true
```

---

## Pod Labels and Selectors

Labels are **key-value tags** that you attach to Pods. They're how Kubernetes connects things (Services → Pods, Deployments → Pods).

```text
  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
  │ Pod 1            │   │ Pod 2            │   │ Pod 3            │
  │                  │   │                  │   │                  │
  │ app: frontend    │   │ app: frontend    │   │ app: backend     │
  │ env: production  │   │ env: staging     │   │ env: production  │
  └─────────────────┘   └─────────────────┘   └─────────────────┘

  Selector: app=frontend
  → Matches: Pod 1, Pod 2

  Selector: app=frontend, env=production
  → Matches: Pod 1 only

  Selector: env=production
  → Matches: Pod 1, Pod 3
```

```bash
# List pods with a specific label
kubectl get pods -l app=frontend

# List pods with multiple label conditions
kubectl get pods -l app=frontend,env=production

# Show labels on pods
kubectl get pods --show-labels

# Add a label to an existing pod
kubectl label pod my-pod team=platform

# Remove a label
kubectl label pod my-pod team-
```

---

## Pod DNS and Networking

```text
Every Pod gets:
  1. Its OWN IP address (e.g., 10.244.1.5)
  2. Can reach OTHER Pods by their IP
  3. Can reach Services by NAME (DNS)

  ┌────────────────┐         ┌────────────────┐
  │ Pod A           │         │ Pod B           │
  │ IP: 10.244.1.5  │ ──────→│ IP: 10.244.2.3  │
  │                 │ direct  │                 │
  │ Can also reach: │         │                 │
  │ my-service:80   │         │                 │
  │ (via DNS)       │         │                 │
  └────────────────┘         └────────────────┘

  ⚠️ Pod IPs change when Pods restart!
  → That's why you use SERVICES (stable addresses)
  → More on this in 05-services-networking.md
```

---

## Common kubectl Commands for Pods

```bash
# Create/update a pod from YAML
kubectl apply -f pod.yaml

# List all pods
kubectl get pods

# List pods with more details (IP, node, etc.)
kubectl get pods -o wide

# Get detailed info about a pod
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Stream logs in real-time
kubectl logs -f <pod-name>

# Logs from a specific container (multi-container pod)
kubectl logs <pod-name> -c <container-name>

# Execute a command inside a running pod
kubectl exec -it <pod-name> -- /bin/bash

# Copy files to/from a pod
kubectl cp local-file.txt <pod-name>:/path/in/container
kubectl cp <pod-name>:/path/in/container local-file.txt

# Delete a pod
kubectl delete pod <pod-name>

# Watch pods in real-time
kubectl get pods --watch

# Get pod YAML definition
kubectl get pod <pod-name> -o yaml
```

---

## Test Your Understanding 🧪

1. **Why should you almost never create Pods directly?**
2. **What happens if a container exceeds its memory limit?**
3. **What's the difference between a liveness probe and a readiness probe?**
4. **In a multi-container Pod, how do containers communicate?**
5. **Why do Pod IPs change, and what should you use instead?**
6. **What runs first — init containers or regular containers?**

<details>
<summary>Click to see answers</summary>

1. Because Pods are ephemeral — if they die, no one recreates them. Deployments manage Pods and automatically replace dead ones.

2. Kubernetes kills the container (OOMKilled) and restarts it. This is why you must set memory limits — without them, one container can eat all node memory and crash everything.

3. **Liveness** = "Is the container alive?" If it fails, K8s RESTARTS the container. **Readiness** = "Can it handle traffic?" If it fails, K8s STOPS SENDING traffic to it but doesn't restart it.

4. Via `localhost` — all containers in a Pod share the same network namespace and can talk on localhost:port. They can also share files via shared volumes.

5. Pod IPs change because Pods are ephemeral — they get destroyed and recreated with new IPs. Use Services instead — they provide a stable IP/DNS name that doesn't change.

6. Init containers run FIRST, in order, one at a time. Regular containers only start after ALL init containers complete successfully.

</details>

---

## What's Next?

➡️ **[04 — Workloads](./04-workloads.md)** — Deployments, ReplicaSets, StatefulSets, DaemonSets, and Jobs
