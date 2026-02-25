# 04 — Workloads

## Why Not Just Create Pods Directly?

```text
If you create a Pod directly:
  ❌ Pod crashes → it stays dead. Nobody recreates it.
  ❌ Node goes down → Pods on it are gone forever.
  ❌ You want 5 copies → you manually create 5 YAML files.
  ❌ You want to update → you delete old pods, create new ones (downtime!)

If you use a WORKLOAD CONTROLLER (Deployment, StatefulSet, etc.):
  ✅ Pod crashes → controller creates a new one automatically
  ✅ Node goes down → Pods reschedule to healthy nodes
  ✅ You want 5 copies → set replicas: 5
  ✅ You want to update → rolling update with zero downtime
```

---

## The Workload Family

```text
┌──────────────────────────────────────────────────────────────────────┐
│                        WORKLOAD TYPES                                │
│                                                                      │
│  ┌─────────────────┐  "Run N copies of my app, keep them running"   │
│  │   Deployment     │  ← 90% of what you'll use                     │
│  └────────┬────────┘                                                │
│           │ manages                                                  │
│  ┌────────▼────────┐  "Ensure exactly N pods are running"           │
│  │   ReplicaSet     │  ← Created automatically by Deployment        │
│  └─────────────────┘                                                │
│                                                                      │
│  ┌─────────────────┐  "Run a copy on EVERY node"                    │
│  │   DaemonSet      │  ← Monitoring agents, log collectors          │
│  └─────────────────┘                                                │
│                                                                      │
│  ┌─────────────────┐  "Stateful apps with stable identity"          │
│  │   StatefulSet    │  ← Databases, message queues                  │
│  └─────────────────┘                                                │
│                                                                      │
│  ┌─────────────────┐  "Run once and finish"                         │
│  │   Job            │  ← Data migration, batch processing           │
│  └─────────────────┘                                                │
│                                                                      │
│  ┌─────────────────┐  "Run on a schedule"                           │
│  │   CronJob        │  ← Nightly backups, hourly reports            │
│  └─────────────────┘                                                │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 1. Deployment (Your Go-To Workload)

### What It Does

```text
Analogy: A RESTAURANT MANAGER

  You tell the manager: "I need 3 chefs working at all times"

  Manager (Deployment):
    ✅ Hires 3 chefs (creates 3 Pods)
    ✅ If a chef calls in sick → hires a replacement
    ✅ If you need a new recipe → gradually replaces chefs
       one at a time (rolling update, zero downtime)
    ✅ If the new recipe is bad → brings back old chefs (rollback)
```

### Deployment → ReplicaSet → Pods Relationship

```text
  ┌──────────────────────────────────────────┐
  │            Deployment                     │
  │            "web-app"                      │
  │            replicas: 3                    │
  │                                          │
  │    ┌─────────────────────────────────┐   │
  │    │       ReplicaSet                 │   │
  │    │       "web-app-6d4f7b"           │   │
  │    │                                  │   │
  │    │   ┌───────┐ ┌───────┐ ┌───────┐ │   │
  │    │   │ Pod 1 │ │ Pod 2 │ │ Pod 3 │ │   │
  │    │   └───────┘ └───────┘ └───────┘ │   │
  │    └─────────────────────────────────┘   │
  └──────────────────────────────────────────┘

  YOU create: Deployment
  Deployment creates: ReplicaSet
  ReplicaSet creates: Pods

  You almost NEVER touch ReplicaSets directly.
```

### Complete Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web-app
spec:
  replicas: 3                    # Run 3 copies of the Pod

  selector:                      # How the Deployment finds its Pods
    matchLabels:
      app: web-app               # "Find Pods with label app=web-app"

  strategy:
    type: RollingUpdate          # Update strategy (default)
    rollingUpdate:
      maxSurge: 1                # Max 1 extra Pod during update
      maxUnavailable: 0          # Never have fewer than 3 running

  template:                      # Pod template — what each Pod looks like
    metadata:
      labels:
        app: web-app             # MUST match selector above!
    spec:
      containers:
        - name: app
          image: my-app:1.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            periodSeconds: 5
```

### How Rolling Updates Work

```text
Current state: v1 running (3 pods)
You update image to v2

Step 1: Create 1 new v2 Pod (maxSurge: 1)
  v1 ✅  v1 ✅  v1 ✅  v2 🔄 (starting)

Step 2: v2 Pod is ready → terminate 1 v1 Pod
  v1 ✅  v1 ✅  v2 ✅  (v1 terminating...)

Step 3: Create another v2 Pod
  v1 ✅  v2 ✅  v2 🔄

Step 4: Ready → terminate another v1
  v2 ✅  v2 ✅  (v1 terminating...)

Step 5: Create last v2 Pod
  v2 ✅  v2 ✅  v2 🔄

Step 6: Done!
  v2 ✅  v2 ✅  v2 ✅

Result: Zero downtime! Users never noticed. 🎉
```

### Deployment Commands

```bash
# Create or update a deployment
kubectl apply -f deployment.yaml

# Check deployment status
kubectl get deployments

# Watch the rollout progress
kubectl rollout status deployment/web-app

# Update the image (triggers rolling update)
kubectl set image deployment/web-app app=my-app:2.0

# View rollout history
kubectl rollout history deployment/web-app

# Rollback to previous version
kubectl rollout undo deployment/web-app

# Rollback to a specific revision
kubectl rollout undo deployment/web-app --to-revision=2

# Scale manually
kubectl scale deployment/web-app --replicas=5

# Pause/resume a rollout
kubectl rollout pause deployment/web-app
kubectl rollout resume deployment/web-app
```

---

## 2. DaemonSet — One Pod Per Node

```text
Analogy: A SECURITY GUARD at every building entrance

  You don't say "I need 5 guards." You say "I need a guard at EVERY entrance."
  New building added? → Guard automatically assigned.
  Building removed? → Guard removed.

  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │  Node 1  │  │  Node 2  │  │  Node 3  │  │  Node 4  │
  │          │  │          │  │          │  │  (new!)   │
  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │  │ ┌──────┐ │
  │ │DaemonS│ │  │ │DaemonS│ │  │ │DaemonS│ │  │ │DaemonS│ │
  │ │Pod   │ │  │ │Pod   │ │  │ │Pod   │ │  │ │Pod   │ │
  │ └──────┘ │  │ └──────┘ │  │ └──────┘ │  │ └──────┘ │
  └──────────┘  └──────────┘  └──────────┘  └──────────┘
                                              ▲
                                              Auto-created!
```

### Common DaemonSet Use Cases

| Use Case | Tool | Why DaemonSet? |
|----------|------|---------------|
| Log collection | Fluentd, Filebeat | Collect logs from every node |
| Monitoring agent | Prometheus Node Exporter | Collect metrics from every node |
| Network plugin | Calico, Cilium | Network rules on every node |
| Storage daemon | GlusterFS, Ceph | Storage driver on every node |
| Security agent | Falco | Security monitoring on every node |

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
        - name: fluentd
          image: fluentd:v1.16
          resources:
            requests:
              cpu: "100m"
              memory: "200Mi"
            limits:
              cpu: "200m"
              memory: "400Mi"
          volumeMounts:
            - name: varlog
              mountPath: /var/log
              readOnly: true
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
```

---

## 3. StatefulSet — For Stateful Applications

```text
Analogy: NUMBERED PARKING SPOTS in a garage

  Deployment: "Park anywhere!" (Pods are interchangeable)
  StatefulSet: "You are ALWAYS in spot #1, #2, #3" (Pods have identity)

  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  Deployment Pods:          StatefulSet Pods:          │
  │  (random names)            (ordered names)            │
  │                                                      │
  │  web-app-6d4f7b-x2k9r     postgres-0                │
  │  web-app-6d4f7b-m3p8s     postgres-1                │
  │  web-app-6d4f7b-k7n2q     postgres-2                │
  │                                                      │
  │  Die & respawn with        Die & respawn with         │
  │  NEW random name           SAME name and storage      │
  └──────────────────────────────────────────────────────┘
```

### StatefulSet vs. Deployment

| Feature | Deployment | StatefulSet |
|---------|-----------|-------------|
| Pod names | Random (`app-xyz123`) | Ordered (`app-0`, `app-1`) |
| Startup order | All at once | One at a time (0, then 1, then 2) |
| Storage | Shared or none | Each Pod gets its own persistent volume |
| Network identity | Random Pod IP | Stable DNS name per Pod |
| Use case | Stateless web apps | Databases, message queues |

### When to Use StatefulSet

```text
Does your app need:
├── Stable network identity? (e.g., master/slave database)
├── Ordered startup/shutdown? (e.g., cluster bootstrapping)
├── Persistent storage per Pod? (e.g., each DB has its own disk)
└── YES to any → StatefulSet

If NO to all → Use Deployment (simpler)
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: "postgres"      # Required: headless service name
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_PASSWORD
              value: "mysecretpassword"
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data

  # Each Pod gets its OWN persistent volume
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

```text
Result:
  postgres-0 → PVC: data-postgres-0 → PV: 10Gi disk
  postgres-1 → PVC: data-postgres-1 → PV: 10Gi disk
  postgres-2 → PVC: data-postgres-2 → PV: 10Gi disk

  Each Pod has its own dedicated storage that survives restarts.

  DNS names (via headless service):
  postgres-0.postgres.default.svc.cluster.local
  postgres-1.postgres.default.svc.cluster.local
  postgres-2.postgres.default.svc.cluster.local
```

---

## 4. Job — Run Once and Finish

```text
Analogy: A MOVING COMPANY

  "Move all furniture from old office to new office."
  Once done → job complete. Don't keep running.

  Deployment = "Keep the restaurant open 24/7" (always running)
  Job         = "Cater this one event" (run once, then done)
```

### Use Cases

| Use Case | Example |
|----------|---------|
| Database migration | Run schema changes against production DB |
| Batch processing | Process all images in a queue |
| Data export | Generate monthly report |
| One-time setup | Initialize a new environment |

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  backoffLimit: 3              # Retry up to 3 times if it fails
  activeDeadlineSeconds: 300   # Timeout after 5 minutes
  template:
    spec:
      restartPolicy: Never     # Required: Never or OnFailure
      containers:
        - name: migrate
          image: my-app:1.0
          command: ["python", "manage.py", "migrate"]
```

### Parallel Jobs

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: process-images
spec:
  completions: 10      # Total tasks to complete
  parallelism: 3       # Run 3 at a time
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: processor
          image: image-processor:1.0
```

```text
Timeline:
  t=0:  [Task 1] [Task 2] [Task 3]           ← 3 running
  t=10: [Task 4] [Task 5] [Task 6]           ← 3 more
  t=20: [Task 7] [Task 8] [Task 9]           ← 3 more
  t=30: [Task 10]                             ← last one
  t=35: ✅ All 10 complete!
```

---

## 5. CronJob — Scheduled Jobs

```text
Analogy: An ALARM CLOCK

  "Every day at 2 AM, run this backup job."
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-backup
spec:
  schedule: "0 2 * * *"        # Run at 2:00 AM every day
  concurrencyPolicy: Forbid    # Don't run if previous is still running
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: backup-tool:1.0
              command: ["./backup.sh"]
```

### Cron Schedule Syntax

```text
  ┌───────────── minute (0 - 59)
  │ ┌───────────── hour (0 - 23)
  │ │ ┌───────────── day of month (1 - 31)
  │ │ │ ┌───────────── month (1 - 12)
  │ │ │ │ ┌───────────── day of week (0 - 6, Sun=0)
  │ │ │ │ │
  * * * * *

  Examples:
  "0 2 * * *"      → Every day at 2:00 AM
  "*/15 * * * *"   → Every 15 minutes
  "0 0 1 * *"      → First day of every month at midnight
  "0 9 * * 1-5"    → 9 AM on weekdays
  "0 */6 * * *"    → Every 6 hours
```

---

## Quick Decision Guide

```text
What do I need?

├── Run my app continuously with N copies?
│   └── Deployment ✅ (90% of the time, this is your answer)
│
├── Run something on EVERY node?
│   └── DaemonSet ✅ (monitoring, logging, networking)
│
├── Run a database or stateful app?
│   └── StatefulSet ✅ (ordered startup, stable identity, own storage)
│
├── Run a one-time task?
│   └── Job ✅ (migration, batch processing)
│
└── Run a task on a schedule?
    └── CronJob ✅ (backups, cleanup, reports)
```

---

## Production Tips

| Tip | Why |
|-----|-----|
| **Always set resource requests/limits** | Prevents one Pod from starving others |
| **Always set health probes** | Enables auto-restart and traffic management |
| **Use `RollingUpdate` strategy** | Zero-downtime deployments |
| **Set `maxUnavailable: 0`** | Never have fewer Pods than desired |
| **Never use `:latest` image tag** | You won't know which version is running |
| **Set `revisionHistoryLimit`** | Limits how many old ReplicaSets are kept (default 10) |
| **Use Pod Disruption Budgets** | Prevents K8s from killing too many Pods during maintenance |

---

## Test Your Understanding 🧪

1. **What's the relationship between Deployment → ReplicaSet → Pod?**
2. **When would you use a StatefulSet instead of a Deployment?**
3. **What's the difference between a Job and a CronJob?**
4. **How does a rolling update achieve zero downtime?**
5. **What does a DaemonSet guarantee?**
6. **How do you rollback a bad deployment?**

<details>
<summary>Click to see answers</summary>

1. You create a Deployment. The Deployment creates a ReplicaSet. The ReplicaSet creates and manages the Pods. During updates, the Deployment creates a NEW ReplicaSet and gradually shifts Pods from old to new.

2. When your app needs: stable network identity (like db-0, db-1), ordered startup/shutdown, or persistent storage per Pod. Examples: databases, message queues, distributed systems like Kafka/Elasticsearch.

3. A **Job** runs once and finishes. A **CronJob** runs Jobs on a schedule (like cron: every hour, every night).

4. It creates new Pods (new version) one at a time. Only after a new Pod is healthy does it remove an old Pod. At no point are there fewer than the desired number of healthy Pods serving traffic.

5. Exactly ONE Pod runs on EVERY node in the cluster. When a new node is added, the DaemonSet automatically schedules a Pod on it.

6. `kubectl rollout undo deployment/<name>` — this switches back to the previous ReplicaSet.

</details>

---

## What's Next?

➡️ **[05 — Services & Networking](./05-services-networking.md)** — How traffic reaches your Pods
