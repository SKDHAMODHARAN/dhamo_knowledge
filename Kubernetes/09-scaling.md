# 09 — Scaling

## The Problem: Fixed Capacity

```text
Imagine a pizza restaurant:

  Friday 6 PM (peak):
    100 orders per hour → 3 chefs can't keep up → customers leave 😡

  Tuesday 2 PM (quiet):
    5 orders per hour → 3 chefs sitting idle → wasting money 💸

  SOLUTION: Auto-scaling
    Peak   → automatically add more chefs
    Quiet  → send extra chefs home

  In Kubernetes terms:
    Peak   → add more Pods (or nodes)
    Quiet  → remove excess Pods (or nodes)
```

---

## Three Types of Scaling

```text
┌────────────────────────────────────────────────────────────────────┐
│                     SCALING IN KUBERNETES                          │
│                                                                    │
│  ┌─────────────────────────┐                                      │
│  │   HPA                   │  Scale PODS horizontally              │
│  │   (Horizontal Pod       │  More traffic → more Pod copies       │
│  │    Autoscaler)          │  "Add more pizza delivery drivers"   │
│  └─────────────────────────┘                                      │
│                                                                    │
│  ┌─────────────────────────┐                                      │
│  │   VPA                   │  Scale PODS vertically                │
│  │   (Vertical Pod         │  Pod needs more CPU/memory → resize  │
│  │    Autoscaler)          │  "Give each driver a bigger car"     │
│  └─────────────────────────┘                                      │
│                                                                    │
│  ┌─────────────────────────┐                                      │
│  │   Cluster Autoscaler    │  Scale NODES                          │
│  │                         │  No room for new Pods → add nodes    │
│  │                         │  "Build more parking spots"          │
│  └─────────────────────────┘                                      │
│                                                                    │
│  They work TOGETHER:                                              │
│  HPA adds Pods → no room on nodes → Cluster Autoscaler adds nodes │
└────────────────────────────────────────────────────────────────────┘
```

| Type | What Scales | Based On | When to Use |
|------|------------|----------|-------------|
| **HPA** | Number of Pods | CPU, memory, custom metrics | Most apps (web servers, APIs) |
| **VPA** | Pod size (CPU/memory) | Actual usage patterns | Right-sizing, batch jobs |
| **Cluster Autoscaler** | Number of Nodes | Pending (unschedulable) Pods | Always (in cloud environments) |

---

## HPA — Horizontal Pod Autoscaler

### How It Works

```text
  ┌──────────────────────────────────────────────────────────────┐
  │                          HPA                                  │
  │                                                              │
  │   Every 15 seconds:                                          │
  │                                                              │
  │   1. Check current metric (e.g., CPU = 80%)                  │
  │   2. Compare to target (e.g., target = 50%)                  │
  │   3. Calculate desired replicas:                             │
  │      desired = current_replicas × (current_value / target)   │
  │      desired = 3 × (80 / 50) = 4.8 → round up to 5          │
  │   4. Scale from 3 to 5 Pods                                  │
  │                                                              │
  │   ┌───┐ ┌───┐ ┌───┐                 ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐
  │   │Pod│ │Pod│ │Pod│   ──scale up──→  │Pod│ │Pod│ │Pod│ │Pod│ │Pod│
  │   │80%│ │85%│ │75%│                  │48%│ │50%│ │52%│ │47%│ │49%│
  │   └───┘ └───┘ └───┘                 └───┘ └───┘ └───┘ └───┘ └───┘
  │   Avg CPU: 80%                       Avg CPU: ~49% ✅         │
  └──────────────────────────────────────────────────────────────┘
```

### HPA YAML

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app               # Which Deployment to scale

  minReplicas: 2                # Never go below 2
  maxReplicas: 20               # Never go above 20

  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60    # Target: 60% average CPU

    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70    # Target: 70% average memory

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300   # Wait 5 min before scaling down
      policies:
        - type: Percent
          value: 25                     # Remove max 25% of Pods at a time
          periodSeconds: 60

    scaleUp:
      stabilizationWindowSeconds: 0     # Scale up immediately
      policies:
        - type: Pods
          value: 4                      # Add max 4 Pods at a time
          periodSeconds: 60
```

### ⚠️ HPA Prerequisite: Resource Requests

```text
HPA needs resource REQUESTS to calculate utilization!

  WITHOUT requests:
    Pod has no CPU request → HPA can't calculate % utilization → HPA won't work!

  WITH requests:
    Pod requests 250m CPU, currently using 200m → 80% utilization → HPA scales

  RULE: If you want HPA, you MUST set resource requests on your containers.
```

### HPA with Custom Metrics

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: queue-worker-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: queue-worker
  minReplicas: 1
  maxReplicas: 50
  metrics:
    - type: External
      external:
        metric:
          name: sqs_queue_length        # Custom metric from Prometheus
        target:
          type: AverageValue
          averageValue: "10"            # Scale if > 10 messages per Pod
```

### HPA Commands

```bash
# Create HPA from CLI (quick)
kubectl autoscale deployment web-app --min=2 --max=20 --cpu-percent=60

# Check HPA status
kubectl get hpa

# Detailed HPA info
kubectl describe hpa web-app-hpa

# Watch HPA in real-time
kubectl get hpa --watch
```

---

## VPA — Vertical Pod Autoscaler

```text
HPA = add MORE Pods (horizontal)
VPA = make Pods BIGGER (vertical)

  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │  HPA:                          VPA:                      │
  │                                                          │
  │  ┌───┐ ┌───┐ ┌───┐            ┌──────────┐              │
  │  │   │ │   │ │   │            │          │              │
  │  │   │ │   │ │   │  ──→       │  BIGGER  │              │
  │  │   │ │   │ │   │            │   POD    │              │
  │  └───┘ └───┘ └───┘            │          │              │
  │  More copies                  └──────────┘              │
  │                                More CPU/memory           │
  └──────────────────────────────────────────────────────────┘
```

### When to Use VPA vs. HPA

| Scenario | Use |
|----------|-----|
| Stateless web app, traffic varies | **HPA** (add more replicas) |
| Database (can't easily add replicas) | **VPA** (give it more CPU/memory) |
| Unsure what resources a Pod needs | **VPA in recommend mode** (it suggests values) |
| Batch processing with variable load | **HPA** (scale workers based on queue length) |

### VPA YAML

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: web-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app

  updatePolicy:
    updateMode: "Auto"          # Auto, Recreate, Initial, Off

  resourcePolicy:
    containerPolicies:
      - containerName: app
        minAllowed:
          cpu: "100m"
          memory: "128Mi"
        maxAllowed:
          cpu: "2"
          memory: "4Gi"
```

### VPA Modes

| Mode | Behavior |
|------|---------|
| **Off** | Only recommends, doesn't change anything (safest to start) |
| **Initial** | Sets resources only when Pod is first created |
| **Auto** | Automatically adjusts (may restart Pods!) |

**⚠️ Never use HPA and VPA on the same metric** (e.g., both on CPU). They'll fight each other.

---

## Cluster Autoscaler — Scale the Infrastructure

```text
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  HPA says: "I need 10 Pods"                                  │
  │  Scheduler says: "But only 3 fit on existing nodes!"         │
  │  7 Pods stuck in PENDING state...                            │
  │                                                              │
  │  ┌────────┐ ┌────────┐ ┌────────┐                            │
  │  │ Node 1 │ │ Node 2 │ │ Node 3 │   Pods: 😊😊😊 😴😴😴😴😴😴😴 │
  │  │ FULL   │ │ FULL   │ │ FULL   │         running  pending   │
  │  └────────┘ └────────┘ └────────┘                            │
  │                                                              │
  │  Cluster Autoscaler: "I see pending Pods. Let me add nodes!" │
  │                                                              │
  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐     │
  │  │ Node 1 │ │ Node 2 │ │ Node 3 │ │ Node 4 │ │ Node 5 │     │
  │  │ FULL   │ │ FULL   │ │ FULL   │ │ new ✅ │ │ new ✅ │     │
  │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘     │
  │                                                              │
  │  All 10 Pods now scheduled and running! 🎉                   │
  │                                                              │
  │  Later, when traffic drops:                                  │
  │  HPA scales down Pods → Nodes 4, 5 are empty →              │
  │  Cluster Autoscaler removes them → saves money 💰            │
  └──────────────────────────────────────────────────────────────┘
```

### How to Set Up (AWS EKS Example)

```yaml
# Cluster Autoscaler deployment (simplified)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
        - name: cluster-autoscaler
          image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.0
          command:
            - ./cluster-autoscaler
            - --v=4
            - --cloud-provider=aws
            - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
            - --balance-similar-node-groups
            - --skip-nodes-with-system-pods=false
            - --scale-down-delay-after-add=10m
            - --scale-down-unneeded-time=10m
```

---

## Complete Scaling Example

```text
Putting it all together:

  User traffic spike → Pods CPU goes from 30% to 90%
                            │
                            ▼
  HPA detects: CPU (90%) > target (60%)
  HPA action: Scale from 3 to 5 Pods
                            │
                            ▼
  Scheduler: "Node 1 and 2 are full. 2 Pods pending!"
                            │
                            ▼
  Cluster Autoscaler: "Pending Pods detected"
  CA action: Add Node 3 to the cluster (3-5 min on AWS)
                            │
                            ▼
  Pending Pods scheduled on Node 3. All 5 running! ✅
                            │
                            ▼
  Traffic drops → CPU back to 20%
  HPA: Scale down from 5 to 2 Pods (after stabilization window)
  CA: Node 3 empty for 10 min → remove it
```

---

## Pod Disruption Budgets — Safe Scaling Down

```text
During scaling down or node maintenance, K8s needs to evict (remove) Pods.
PDB ensures not TOO MANY Pods are removed at once.

  Without PDB:
    K8s evicts all 3 Pods at once during node drain → service outage! 😱

  With PDB (minAvailable: 2):
    K8s evicts 1 Pod, waits for replacement, evicts next → service stays up ✅
```

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-app-pdb
spec:
  minAvailable: 2              # At least 2 Pods must be running at all times
  # OR
  # maxUnavailable: 1          # At most 1 Pod can be down at a time
  selector:
    matchLabels:
      app: web-app
```

---

## Scaling Decision Guide

```text
My app is slow under load. What do I scale?

├── Is the problem CPU/memory per Pod?
│   ├── YES → VPA (make Pods bigger)
│   └── NO ↓
│
├── Can my app run as multiple copies?
│   ├── YES → HPA (add more Pods)
│   │   └── Based on CPU? → Resource metric
│   │   └── Based on queue length? → Custom metric
│   └── NO (stateful, single-instance)
│       └── VPA or manual scaling
│
└── HPA is trying to scale but Pods are stuck in Pending?
    └── Cluster Autoscaler (add more nodes)
```

---

## Production Best Practices

| Practice | Why |
|----------|-----|
| **Always set `minReplicas >= 2`** | Single Pod = single point of failure |
| **Set `maxReplicas` to prevent runaway** | Unlimited scaling = unlimited cloud bill |
| **Use `scaleDown.stabilizationWindowSeconds`** | Prevents flapping (scale up/down/up/down) |
| **Set resource requests accurately** | HPA uses requests to calculate utilization |
| **Use PodDisruptionBudgets** | Prevents too many Pods going down at once |
| **Start with HPA + Cluster Autoscaler** | VPA is more complex, add later |
| **Monitor scaling events** | `kubectl describe hpa` shows recent scaling decisions |

---

## Test Your Understanding 🧪

1. **What's the difference between HPA and VPA?**
2. **Why must you set resource requests for HPA to work?**
3. **What triggers the Cluster Autoscaler to add nodes?**
4. **Can you use HPA and VPA on the same metric simultaneously?**
5. **What is a PodDisruptionBudget and why do you need it?**

<details>
<summary>Click to see answers</summary>

1. **HPA** scales horizontally — adds/removes Pod copies. **VPA** scales vertically — increases/decreases CPU/memory for existing Pods. HPA = more drivers, VPA = bigger car.

2. HPA calculates utilization as a percentage of requests. If CPU request is 250m and current usage is 200m, utilization is 80%. Without requests, HPA can't calculate the percentage and won't work.

3. When Pods are in `Pending` state because no node has enough resources to schedule them. The CA detects these unschedulable Pods and adds nodes.

4. **No.** They'll fight each other — HPA tries to add Pods while VPA tries to resize them based on the same metric. Use them on different metrics or use only one.

5. A PDB defines the minimum number of Pods that must stay available during disruptions (node drains, scaling down). It prevents K8s from evicting too many Pods at once, avoiding service outages during maintenance.

</details>

---

## What's Next?

➡️ **[10 — Helm & Packaging](./10-helm-packaging.md)** — Package and share Kubernetes applications
