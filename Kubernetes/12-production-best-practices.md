# 12 — Production Best Practices

## The Difference Between "It Works" and "It's Production-Ready"

```text
  "It works on my laptop"  ≠  "It can handle real users"

  DEV:
    ✅ 1 replica, no health checks, no limits, :latest tag, root user
    "Look, it runs!"

  PRODUCTION:
    ✅ Multiple replicas across zones
    ✅ Health checks (liveness + readiness + startup)
    ✅ Resource requests AND limits
    ✅ Pinned image versions
    ✅ Non-root container
    ✅ RBAC, NetworkPolicies, PodSecurityStandards
    ✅ Monitoring, alerting, logging
    ✅ Auto-scaling (HPA + Cluster Autoscaler)
    ✅ PodDisruptionBudgets
    ✅ Graceful shutdown handling
    ✅ Rolling update strategy
    "It can survive Black Friday traffic and a 2 AM node failure"
```

---

## The Production-Ready Deployment (Complete Example)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
    version: "2.5.0"
    team: platform
spec:
  replicas: 3
  revisionHistoryLimit: 5

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

  selector:
    matchLabels:
      app: web-app

  template:
    metadata:
      labels:
        app: web-app
        version: "2.5.0"
    spec:
      serviceAccountName: web-app-sa
      automountServiceAccountToken: false

      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000

      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: web-app
                topologyKey: kubernetes.io/hostname

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web-app

      terminationGracePeriodSeconds: 30

      containers:
        - name: app
          image: registry.company.com/web-app:2.5.0    # Pinned version!
          imagePullPolicy: IfNotPresent

          ports:
            - name: http
              containerPort: 8080
              protocol: TCP

          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1"
              memory: "512Mi"

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          startupProbe:
            httpGet:
              path: /healthz
              port: http
            failureThreshold: 30
            periodSeconds: 10

          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 0
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 0
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3

          envFrom:
            - configMapRef:
                name: web-app-config
            - secretRef:
                name: web-app-secrets

          volumeMounts:
            - name: tmp
              mountPath: /tmp

      volumes:
        - name: tmp
          emptyDir: {}
```

---

## Checklist: Go/No-Go for Production

### 🏗️ Deployment Configuration

| Item | Why | Status |
|------|-----|--------|
| `replicas >= 2` | Single replica = single point of failure | ☐ |
| `maxUnavailable: 0` | Never have fewer than desired during updates | ☐ |
| `revisionHistoryLimit` set | Control how many old ReplicaSets are kept | ☐ |
| Image tag is pinned version (NOT `:latest`) | Know exactly what's running | ☐ |
| `imagePullPolicy: IfNotPresent` | Avoid pulling on every restart | ☐ |
| Use private container registry | Control what runs in your cluster | ☐ |

### 💊 Health & Resilience

| Item | Why | Status |
|------|-----|--------|
| Liveness probe configured | Auto-restart deadlocked containers | ☐ |
| Readiness probe configured | Don't send traffic to unhealthy Pods | ☐ |
| Startup probe for slow-starting apps | Give time to boot before checking | ☐ |
| `terminationGracePeriodSeconds` set | Allow graceful shutdown | ☐ |
| PodDisruptionBudget created | Prevent mass eviction during maintenance | ☐ |
| Pod anti-affinity rules | Spread Pods across nodes | ☐ |
| Topology spread across zones | Survive availability zone failure | ☐ |

### 📦 Resource Management

| Item | Why | Status |
|------|-----|--------|
| CPU request set | Scheduler knows how much to reserve | ☐ |
| Memory request set | Scheduler knows how much to reserve | ☐ |
| CPU limit set | Prevent CPU starvation of other Pods | ☐ |
| Memory limit set | Prevent OOM killing other Pods | ☐ |
| HPA configured | Handle traffic spikes automatically | ☐ |
| `minReplicas >= 2` in HPA | Always have redundancy | ☐ |
| `maxReplicas` capped | Prevent runaway scaling (and bills) | ☐ |

### 🔒 Security

| Item | Why | Status |
|------|-----|--------|
| `runAsNonRoot: true` | Prevent root container escape | ☐ |
| `readOnlyRootFilesystem: true` | Prevent filesystem tampering | ☐ |
| `allowPrivilegeEscalation: false` | Container can't gain privileges | ☐ |
| Drop ALL capabilities | Minimize Linux kernel access | ☐ |
| Dedicated ServiceAccount (not default) | Least-privilege API access | ☐ |
| `automountServiceAccountToken: false` (if not needed) | Don't expose token unnecessarily | ☐ |
| NetworkPolicy restricting traffic | Only allow needed communication | ☐ |
| Pod Security Standard: `restricted` | Enforce security at namespace level | ☐ |
| Secrets not in Git | Use external secrets management | ☐ |
| Secrets encrypted at rest in etcd | Protect stored secrets | ☐ |

### 📊 Observability

| Item | Why | Status |
|------|-----|--------|
| Structured (JSON) logging | Machine-parseable, queryable | ☐ |
| Centralized log collection | Don't rely on `kubectl logs` | ☐ |
| Prometheus metrics exposed | Monitor application health | ☐ |
| Grafana dashboard created | Visualize app metrics | ☐ |
| Alerts configured for errors | Get notified before users do | ☐ |
| Alerts configured for latency | Catch performance degradation | ☐ |
| Alert routing (Slack/PagerDuty) | Right people notified | ☐ |

### 🧹 Operational Readiness

| Item | Why | Status |
|------|-----|--------|
| CI/CD pipeline deploys via Helm | Repeatable, auditable deploys | ☐ |
| Rollback procedure documented | Fast recovery from bad deploys | ☐ |
| etcd backup automated | Recover from cluster failure | ☐ |
| Cluster Autoscaler configured | Handle infrastructure scaling | ☐ |
| Resource quotas per namespace | Prevent one team from hogging cluster | ☐ |
| Disaster recovery plan | What if the entire cluster goes down? | ☐ |

---

## Graceful Shutdown — A Deep Dive

```text
When K8s kills a Pod (during scale-down, update, or node drain):

  1. Pod marked for termination
  2. Pod removed from Service endpoints (no new traffic)
  3. SIGTERM sent to container (POLITE: "please shut down")
  4. Container has terminationGracePeriodSeconds to finish work
  5. If not stopped → SIGKILL (FORCED: "you're done NOW")

  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  Timeline:                                                   │
  │                                                              │
  │  t=0s    SIGTERM sent                                        │
  │  t=0-30s Container should:                                   │
  │          ├── Stop accepting new requests                     │
  │          ├── Finish processing current requests              │
  │          ├── Close database connections                      │
  │          └── Flush logs and metrics                          │
  │  t=30s   If still running → SIGKILL (forced kill)            │
  │                                                              │
  │  YOUR APP MUST HANDLE SIGTERM!                               │
  │  Many frameworks do this automatically (Express, Spring, etc.)│
  └──────────────────────────────────────────────────────────────┘
```

### Lifecycle Hooks

```yaml
containers:
  - name: app
    image: my-app:2.5.0
    lifecycle:
      preStop:
        exec:
          command: ["sh", "-c", "sleep 5"]
```

**Why `sleep 5`?** There's a race condition: the endpoint removal (step 2) and SIGTERM (step 3) happen in parallel. The `sleep 5` gives kube-proxy time to update routing rules before your app starts shutting down.

---

## Resource Quotas — Prevent Cluster Abuse

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-alpha
spec:
  hard:
    requests.cpu: "20"          # Total CPU requests across all Pods
    requests.memory: "40Gi"
    limits.cpu: "40"
    limits.memory: "80Gi"
    pods: "50"                  # Max 50 Pods in this namespace
    services: "10"
    persistentvolumeclaims: "20"

---
# LimitRange — set defaults for Pods that don't specify resources
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-alpha
spec:
  limits:
    - type: Container
      default:                  # Default limits (if not specified)
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:           # Default requests (if not specified)
        cpu: "250m"
        memory: "128Mi"
      max:                      # Maximum any container can request
        cpu: "4"
        memory: "8Gi"
      min:                      # Minimum any container must request
        cpu: "50m"
        memory: "64Mi"
```

---

## Multi-Tenancy — Namespace-Per-Team Strategy

```text
  ┌──────────────────────────────────────────────────────────────┐
  │                        CLUSTER                               │
  │                                                              │
  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
  │  │ ns: team-alpha │  │ ns: team-beta  │  │ ns: platform   │   │
  │  │               │  │               │  │               │   │
  │  │ ResourceQuota │  │ ResourceQuota │  │ ResourceQuota │   │
  │  │ NetworkPolicy │  │ NetworkPolicy │  │ NetworkPolicy │   │
  │  │ LimitRange    │  │ LimitRange    │  │ LimitRange    │   │
  │  │ RBAC (team)   │  │ RBAC (team)   │  │ RBAC (team)   │   │
  │  │ PSS: restrict │  │ PSS: restrict │  │ PSS: baseline │   │
  │  └───────────────┘  └───────────────┘  └───────────────┘   │
  │                                                              │
  │  Each team gets:                                             │
  │  ├── Their own namespace                                     │
  │  ├── Resource quotas (can't hog the cluster)                │
  │  ├── RBAC (can only access their namespace)                 │
  │  ├── NetworkPolicies (isolated from other teams)            │
  │  └── Pod Security Standards (enforced)                      │
  └──────────────────────────────────────────────────────────────┘
```

---

## CI/CD Pipeline Pattern

```text
  Developer pushes code
         │
         ▼
  ┌──────────────┐
  │   CI          │
  │  1. Lint code │
  │  2. Run tests │
  │  3. Build     │
  │     Docker    │
  │     image     │
  │  4. Push to   │
  │     registry  │
  │  5. Scan for  │
  │     vulns     │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │   CD          │
  │  6. helm      │
  │     upgrade   │
  │     --install │
  │     --atomic  │
  │  7. Run smoke │
  │     tests     │
  │  8. Monitor   │
  │     for 5 min │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │  If errors:   │
  │  helm rollback│
  │  Alert team   │
  └──────────────┘
```

### Key CI/CD Principles

| Principle | Why |
|-----------|-----|
| Build once, deploy everywhere | Same image for dev/staging/prod |
| Use `--atomic` flag | Auto-rollback if deploy fails |
| Scan images for vulnerabilities | Catch CVEs before production |
| Run smoke tests after deploy | Verify basic functionality |
| Use GitOps (ArgoCD/FluxCD) | Git is the source of truth for cluster state |

---

## Cost Optimization

```text
  ┌──────────────────────────────────────────────────────────────┐
  │  COST OPTIMIZATION STRATEGIES                                │
  │                                                              │
  │  1. RIGHT-SIZE resources (VPA recommendations)               │
  │     Don't allocate 4 CPU if you use 0.2 CPU                  │
  │                                                              │
  │  2. USE SPOT/PREEMPTIBLE INSTANCES for non-critical          │
  │     70-90% cheaper, but can be reclaimed                     │
  │                                                              │
  │  3. CLUSTER AUTOSCALER scales nodes down when idle           │
  │     Don't pay for empty nodes                                │
  │                                                              │
  │  4. SET RESOURCE QUOTAS per namespace                        │
  │     Prevent teams from over-provisioning                     │
  │                                                              │
  │  5. USE HPA to match capacity to demand                     │
  │     Scale down when traffic drops                            │
  │                                                              │
  │  6. REVIEW UNUSED RESOURCES regularly                        │
  │     Orphaned PVs, unused LoadBalancers, idle namespaces      │
  └──────────────────────────────────────────────────────────────┘
```

---

## What's Next?

➡️ **[13 — Troubleshooting](./13-troubleshooting.md)** — Debug like a pro when things break
