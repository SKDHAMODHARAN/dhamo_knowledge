# 08 — RBAC & Security

## Why Security Matters in Kubernetes

```text
Imagine your cluster is a CORPORATE OFFICE BUILDING:

  WITHOUT security:
    ❌ Anyone can enter any room (access any namespace)
    ❌ The janitor can access the CEO's safe (Pods access Secrets)
    ❌ A hacked computer compromises the entire building
    ❌ No security cameras (no audit logs)

  WITH proper security:
    ✅ Keycards control who enters which floor (RBAC)
    ✅ Each person only has access to what they need (least privilege)
    ✅ Security cameras record everything (audit logs)
    ✅ Visitors get temporary badges (ServiceAccounts with scoped permissions)
```

---

## RBAC — Role-Based Access Control

### The Three Questions RBAC Answers

```text
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  1. WHO?     → Subject (User, Group, ServiceAccount)         │
│  2. CAN DO?  → Verbs (get, list, create, delete, update)    │
│  3. ON WHAT? → Resources (pods, services, secrets, etc.)     │
│                                                              │
│  Example:                                                    │
│  "Developer Alice CAN get and list Pods in namespace dev"    │
│                                                              │
│  WHO:    Alice (User)                                        │
│  CAN DO: get, list                                           │
│  WHAT:   pods                                                │
│  WHERE:  namespace "dev"                                     │
└──────────────────────────────────────────────────────────────┘
```

### The Four RBAC Objects

```text
┌────────────────────────────────────────────────────────────────────┐
│                      RBAC BUILDING BLOCKS                         │
│                                                                    │
│  ┌─────────────────────────┐    ┌──────────────────────────────┐  │
│  │         ROLE             │    │       CLUSTER ROLE            │  │
│  │                         │    │                              │  │
│  │  "What actions are      │    │  Same, but cluster-wide      │  │
│  │   allowed?"              │    │  (all namespaces)            │  │
│  │                         │    │                              │  │
│  │  Scoped to ONE          │    │  Not scoped — applies        │  │
│  │  namespace              │    │  everywhere                  │  │
│  └───────────┬─────────────┘    └──────────────┬───────────────┘  │
│              │                                 │                   │
│         binds to                          binds to                 │
│              │                                 │                   │
│  ┌───────────▼─────────────┐    ┌──────────────▼───────────────┐  │
│  │     ROLE BINDING        │    │    CLUSTER ROLE BINDING       │  │
│  │                         │    │                              │  │
│  │  "WHO gets this Role?"  │    │  "WHO gets this ClusterRole?"│  │
│  │                         │    │                              │  │
│  │  Links Role to User/    │    │  Links ClusterRole to User/  │  │
│  │  Group/ServiceAccount   │    │  Group/ServiceAccount        │  │
│  └─────────────────────────┘    └──────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

| Object | Scope | Purpose |
|--------|-------|---------|
| **Role** | Single namespace | Define permissions within one namespace |
| **ClusterRole** | Entire cluster | Define permissions across all namespaces |
| **RoleBinding** | Single namespace | Assign a Role to a subject |
| **ClusterRoleBinding** | Entire cluster | Assign a ClusterRole to a subject |

---

## Step-by-Step Example: Give a Developer Read Access

### Step 1: Create a Role (What's Allowed)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: pod-reader
rules:
  - apiGroups: [""]          # "" = core API group (pods, services, etc.)
    resources: ["pods"]
    verbs: ["get", "list", "watch"]

  - apiGroups: [""]
    resources: ["pods/log"]   # Can also read pod logs
    verbs: ["get"]
```

### Step 2: Create a RoleBinding (Who Gets the Role)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: development
subjects:
  - kind: User
    name: alice@company.com
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader            # The Role from Step 1
  apiGroup: rbac.authorization.k8s.io
```

```text
Result:
  alice@company.com CAN:
    ✅ kubectl get pods -n development
    ✅ kubectl describe pod my-pod -n development
    ✅ kubectl logs my-pod -n development

  alice@company.com CANNOT:
    ❌ kubectl delete pod my-pod -n development    (no "delete" verb)
    ❌ kubectl get pods -n production               (wrong namespace)
    ❌ kubectl get secrets -n development           (wrong resource)
```

---

## Common RBAC Verbs

| Verb | What It Allows | kubectl Example |
|------|---------------|----------------|
| `get` | Read a single resource | `kubectl get pod my-pod` |
| `list` | List all resources | `kubectl get pods` |
| `watch` | Stream changes in real-time | `kubectl get pods --watch` |
| `create` | Create new resources | `kubectl apply -f pod.yaml` |
| `update` | Modify existing resources | `kubectl edit pod my-pod` |
| `patch` | Partially update resources | `kubectl patch pod ...` |
| `delete` | Remove resources | `kubectl delete pod my-pod` |
| `exec` | Execute commands in containers | `kubectl exec -it pod -- bash` |

---

## ServiceAccounts — Identity for Pods

```text
Humans use Users/Groups.
Pods use ServiceAccounts.

  Every Pod runs as a ServiceAccount.
  If you don't specify one, it uses "default" (which has minimal permissions).

  ┌──────────────────────────────────────────────────┐
  │                                                  │
  │  Human (Developer)                               │
  │    → authenticates with certificate/token         │
  │    → bound to Roles via RoleBinding              │
  │                                                  │
  │  Pod (Application)                               │
  │    → runs as a ServiceAccount                     │
  │    → ServiceAccount bound to Roles               │
  │    → Can call K8s API with its permissions        │
  │                                                  │
  │  Example: A monitoring app needs to LIST pods     │
  │  → Create ServiceAccount "monitoring"             │
  │  → Create Role allowing "list pods"               │
  │  → Bind them together                             │
  │  → Pod runs as ServiceAccount "monitoring"        │
  └──────────────────────────────────────────────────┘
```

### Complete ServiceAccount Example

```yaml
# 1. Create ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-sa
  namespace: monitoring

---
# 2. Create ClusterRole (needs to list pods across all namespaces)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-lister
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]

---
# 3. Bind ClusterRole to ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-pod-lister
subjects:
  - kind: ServiceAccount
    name: monitoring-sa
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: pod-lister
  apiGroup: rbac.authorization.k8s.io

---
# 4. Pod uses the ServiceAccount
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitoring-app
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: monitoring
  template:
    metadata:
      labels:
        app: monitoring
    spec:
      serviceAccountName: monitoring-sa   # ← Use our ServiceAccount
      automountServiceAccountToken: true
      containers:
        - name: monitor
          image: monitoring-tool:1.0
```

---

## Pod Security — Hardening Containers

### Security Context

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:                      # Pod-level security
    runAsNonRoot: true                  # Don't run as root
    runAsUser: 1000                     # Run as user ID 1000
    runAsGroup: 3000                    # Run as group ID 3000
    fsGroup: 2000                       # Filesystem group

  containers:
    - name: app
      image: my-app:1.0
      securityContext:                  # Container-level security
        allowPrivilegeEscalation: false # Can't become root
        readOnlyRootFilesystem: true    # Can't write to container FS
        capabilities:
          drop:
            - ALL                       # Drop all Linux capabilities
```

### Why Each Setting Matters

```text
┌──────────────────────────────────────────────────────────────────┐
│  SECURITY SETTING               │  WHY IT MATTERS               │
│─────────────────────────────────┼───────────────────────────────│
│  runAsNonRoot: true             │  Root in container ≈ root on  │
│                                 │  node. Huge attack surface.   │
│                                 │                               │
│  readOnlyRootFilesystem: true   │  Attacker can't write         │
│                                 │  malware to the filesystem.   │
│                                 │                               │
│  allowPrivilegeEscalation: false│  Container process can't      │
│                                 │  gain additional privileges.  │
│                                 │                               │
│  capabilities.drop: ALL         │  Remove Linux kernel powers   │
│                                 │  the container doesn't need.  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Pod Security Standards (PSS)

Kubernetes has three built-in security levels:

```text
  ┌────────────────────────────────────────────────────────────────┐
  │                                                                │
  │  PRIVILEGED                                                    │
  │  ├── No restrictions at all                                    │
  │  ├── For: system-level workloads (CNI, CSI drivers)            │
  │  └── ⚠️ NEVER for application workloads                        │
  │                                                                │
  │  BASELINE                                                      │
  │  ├── Prevents known privilege escalations                      │
  │  ├── For: most standard workloads                              │
  │  └── Blocks: hostNetwork, hostPID, privileged containers       │
  │                                                                │
  │  RESTRICTED ← AIM FOR THIS IN PRODUCTION                      │
  │  ├── Strictest: non-root, read-only FS, drop capabilities     │
  │  ├── For: security-sensitive workloads                         │
  │  └── Blocks: running as root, privilege escalation             │
  │                                                                │
  └────────────────────────────────────────────────────────────────┘
```

### Enforce at Namespace Level

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

## Common RBAC Patterns

### Read-Only Developer

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: staging
  name: developer-readonly
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "services", "jobs", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
```

### Deployer (CI/CD Pipeline)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: deployer
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
```

### Namespace Admin

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-alpha-admin
  namespace: team-alpha
subjects:
  - kind: Group
    name: team-alpha-devs
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin                # Built-in ClusterRole
  apiGroup: rbac.authorization.k8s.io
```

---

## Built-in ClusterRoles

| ClusterRole | Permissions | Use For |
|-------------|------------|---------|
| `cluster-admin` | EVERYTHING | Platform team only, break-glass |
| `admin` | All resources in a namespace | Team leads, namespace owners |
| `edit` | Create/update/delete most resources | Developers (active) |
| `view` | Read-only on most resources | Developers (read-only), auditors |

---

## Security Checklist for Production

```text
  ┌──────────────────────────────────────────────────────────────────┐
  │  PRODUCTION SECURITY CHECKLIST                                  │
  │                                                                  │
  │  □ Enable RBAC (default since K8s 1.6+)                         │
  │  □ No Pod uses the "default" ServiceAccount                     │
  │  □ Every Pod has a dedicated ServiceAccount with minimal perms   │
  │  □ automountServiceAccountToken: false when API access not needed│
  │  □ Pods run as non-root (runAsNonRoot: true)                    │
  │  □ Read-only root filesystem where possible                     │
  │  □ Drop all capabilities, add only what's needed                │
  │  □ NetworkPolicies restrict Pod-to-Pod traffic                  │
  │  □ Secrets encrypted at rest in etcd                            │
  │  □ PSS "restricted" enforced on production namespaces           │
  │  □ Image pull from private registry only                        │
  │  □ No `:latest` tags — use immutable digests or pinned versions │
  │  □ Enable audit logging                                         │
  │  □ Regularly review RBAC bindings                               │
  └──────────────────────────────────────────────────────────────────┘
```

---

## Useful kubectl Commands for RBAC

```bash
# Check what YOU can do
kubectl auth can-i create pods
kubectl auth can-i delete deployments -n production

# Check what a specific user can do
kubectl auth can-i list secrets -n production --as=alice@company.com

# Check what a ServiceAccount can do
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:monitoring-sa

# List all roles in a namespace
kubectl get roles -n development

# List all ClusterRoles
kubectl get clusterroles

# List all RoleBindings
kubectl get rolebindings -n development

# List all ClusterRoleBindings
kubectl get clusterrolebindings

# Describe a role to see its permissions
kubectl describe role pod-reader -n development
```

---

## Test Your Understanding 🧪

1. **What are the three questions RBAC answers?**
2. **What's the difference between a Role and a ClusterRole?**
3. **What identity do Pods use to interact with the K8s API?**
4. **Why should containers run as non-root?**
5. **What does `readOnlyRootFilesystem: true` prevent?**

<details>
<summary>Click to see answers</summary>

1. **WHO** (Subject — User, Group, or ServiceAccount) **CAN DO** (Verbs — get, list, create, delete) **ON WHAT** (Resources — pods, services, secrets).

2. **Role** is scoped to a single namespace. **ClusterRole** applies cluster-wide across all namespaces. Use Role when permissions are namespace-specific, ClusterRole when they need to span namespaces.

3. **ServiceAccounts.** Every Pod runs as a ServiceAccount. If you don't specify one, it uses "default." Best practice: create dedicated ServiceAccounts with minimal permissions.

4. Root inside a container can potentially escape to the host node with root privileges. Running as non-root limits the damage an attacker can do if they compromise the container.

5. It prevents the container from writing to its own filesystem. This blocks attackers from dropping malware, modifying binaries, or tampering with config files inside the container.

</details>

---

## What's Next?

➡️ **[09 — Scaling](./09-scaling.md)** — Auto-scaling apps and clusters
