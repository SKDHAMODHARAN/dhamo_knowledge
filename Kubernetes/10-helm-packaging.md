# 10 — Helm & Packaging

## The Problem: YAML Sprawl

```text
A real-world app in Kubernetes needs:
  - Deployment.yaml
  - Service.yaml
  - ConfigMap.yaml
  - Secret.yaml
  - Ingress.yaml
  - HPA.yaml
  - PDB.yaml
  - ServiceAccount.yaml
  - NetworkPolicy.yaml
  ... and more

Now multiply that by 3 environments (dev, staging, prod).
That's 27+ YAML files, mostly identical with small differences.

  ❌ Copy-paste hell
  ❌ Forgot to update the image version in one file
  ❌ Different environments drift apart
  ❌ Hard to share with other teams

  SOLUTION: Helm — the package manager for Kubernetes.
```

---

## What Is Helm?

```text
Think of it as: apt/brew/npm, but for Kubernetes

  npm install express          → installs Express.js with all dependencies
  helm install my-app ./chart  → installs your app with all K8s resources

  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  Without Helm:                                               │
  │    kubectl apply -f deployment.yaml                          │
  │    kubectl apply -f service.yaml                             │
  │    kubectl apply -f configmap.yaml                           │
  │    kubectl apply -f ingress.yaml                             │
  │    kubectl apply -f hpa.yaml                                 │
  │    ... (repeat for each environment)                         │
  │                                                              │
  │  With Helm:                                                  │
  │    helm install my-app ./my-chart -f prod-values.yaml        │
  │    (ONE command deploys everything) ✅                        │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

---

## Helm Concepts

| Concept | What It Is | Analogy |
|---------|-----------|---------|
| **Chart** | A package of K8s templates | An npm package |
| **Values** | Variables that customize the chart | `package.json` config |
| **Release** | An installed instance of a chart | A running instance of the package |
| **Repository** | Where charts are stored | npm registry |
| **Template** | YAML with Go template placeholders | A template with `{{ .Values.name }}` |

```text
  Chart (template)  +  Values (config)  =  Release (running app)

  ┌──────────────────┐   ┌───────────────┐   ┌──────────────────┐
  │  Chart            │   │  Values        │   │  Release          │
  │                  │ + │               │ = │                  │
  │  deployment.yaml │   │  replicas: 3  │   │  3 Pods running  │
  │  {{ .Values.     │   │  image: v2.0  │   │  image v2.0      │
  │    replicas }}    │   │  env: prod    │   │  in prod namespace│
  └──────────────────┘   └───────────────┘   └──────────────────┘
```

---

## Chart Structure

```text
my-app-chart/
├── Chart.yaml            # Chart metadata (name, version, description)
├── values.yaml           # Default values (overridden per environment)
├── charts/               # Sub-charts (dependencies)
├── templates/            # Kubernetes YAML templates
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── hpa.yaml
│   ├── _helpers.tpl      # Reusable template functions
│   └── NOTES.txt         # Post-install instructions shown to user
└── .helmignore           # Files to ignore when packaging
```

### Chart.yaml

```yaml
apiVersion: v2
name: my-web-app
description: A web application deployed on Kubernetes
type: application
version: 1.0.0             # Chart version (changes when chart changes)
appVersion: "2.5.0"        # App version (your actual app version)
```

### values.yaml (Defaults)

```yaml
replicaCount: 2

image:
  repository: my-app
  tag: "2.5.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  host: ""

resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilization: 60

env:
  LOG_LEVEL: "info"
  DATABASE_HOST: "localhost"
```

### templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu }}
              memory: {{ .Values.resources.requests.memory }}
            limits:
              cpu: {{ .Values.resources.limits.cpu }}
              memory: {{ .Values.resources.limits.memory }}
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
```

### templates/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-service
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
```

---

## Per-Environment Values

```yaml
# values-dev.yaml
replicaCount: 1
image:
  tag: "latest"
env:
  LOG_LEVEL: "debug"
  DATABASE_HOST: "dev-db.internal"

# values-staging.yaml
replicaCount: 2
image:
  tag: "2.5.0-rc1"
env:
  LOG_LEVEL: "info"
  DATABASE_HOST: "staging-db.internal"

# values-prod.yaml
replicaCount: 5
image:
  tag: "2.5.0"
autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 20
ingress:
  enabled: true
  host: "myapp.com"
env:
  LOG_LEVEL: "warn"
  DATABASE_HOST: "prod-db.internal"
```

```bash
# Deploy to dev
helm install my-app ./my-app-chart -f values-dev.yaml -n development

# Deploy to staging
helm install my-app ./my-app-chart -f values-staging.yaml -n staging

# Deploy to production
helm install my-app ./my-app-chart -f values-prod.yaml -n production
```

```text
Same chart, different values = different environments ✅
  ┌──────────────────────────────────────────────────────┐
  │                                                      │
  │  Chart (ONE template)                                │
  │    + values-dev.yaml    → Dev release  (1 replica)   │
  │    + values-staging.yaml→ Staging release (2 replicas)│
  │    + values-prod.yaml   → Prod release (5 replicas)  │
  │                                                      │
  └──────────────────────────────────────────────────────┘
```

---

## Essential Helm Commands

```bash
# ─── INSTALL & UPGRADE ───
# Install a chart
helm install <release-name> <chart> -f values.yaml -n <namespace>

# Upgrade (update) a release
helm upgrade <release-name> <chart> -f values.yaml -n <namespace>

# Install or upgrade (idempotent — safe to run repeatedly)
helm upgrade --install <release-name> <chart> -f values.yaml -n <namespace>

# ─── INSPECT ───
# List all releases
helm list -n <namespace>
helm list --all-namespaces

# Check release status
helm status <release-name> -n <namespace>

# See what values a release is using
helm get values <release-name> -n <namespace>

# See the rendered (final) YAML without installing
helm template <release-name> <chart> -f values.yaml

# ─── ROLLBACK ───
# View release history
helm history <release-name> -n <namespace>

# Rollback to previous version
helm rollback <release-name> <revision> -n <namespace>

# ─── DELETE ───
# Uninstall a release
helm uninstall <release-name> -n <namespace>

# ─── CHARTS ───
# Create a new chart scaffold
helm create my-new-chart

# Lint (validate) a chart
helm lint ./my-chart

# Package a chart into a .tgz file
helm package ./my-chart

# ─── REPOSITORIES ───
# Add a chart repository
helm repo add bitnami https://charts.bitnami.com/bitnami

# Search for charts
helm search repo nginx

# Update repo index
helm repo update
```

---

## Using Community Charts

```bash
# Add popular chart repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install PostgreSQL
helm install my-postgres bitnami/postgresql \
  --set auth.postgresPassword=mypassword \
  --set primary.persistence.size=20Gi \
  -n database

# Install Prometheus + Grafana
helm install monitoring prometheus/kube-prometheus-stack \
  -n monitoring --create-namespace

# Install NGINX Ingress Controller
helm install ingress bitnami/nginx-ingress-controller \
  -n ingress --create-namespace
```

---

## Helm Template Syntax Cheat Sheet

| Syntax | What It Does | Example |
|--------|-------------|---------|
| `{{ .Values.x }}` | Insert a value | `{{ .Values.replicaCount }}` → `3` |
| `{{ .Release.Name }}` | Release name | `my-app` |
| `{{ .Release.Namespace }}` | Namespace | `production` |
| `{{ .Chart.Name }}` | Chart name | `my-web-app` |
| `{{- if .Values.x }}` | Conditional | Only include block if x is truthy |
| `{{- range }}` | Loop | Iterate over a list/map |
| `{{ quote .Values.x }}` | Quote a value | `"my-value"` |
| `{{ default "x" .Values.y }}` | Default value | Use "x" if y is not set |
| `{{ include "tpl" . }}` | Include a helper template | Reuse common definitions |

### Conditional Example

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}-ingress
spec:
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .Release.Name }}-service
                port:
                  number: {{ .Values.service.port }}
{{- end }}
```

---

## Production Best Practices

| Practice | Why |
|----------|-----|
| **Use `helm upgrade --install`** | Idempotent — works for both first install and updates |
| **Always use `-f values.yaml`** | Don't use `--set` for complex configs (not version-controlled) |
| **Pin chart versions** | `helm install app bitnami/nginx --version 15.3.1` |
| **Use `helm template` before applying** | Preview what will be deployed |
| **Store values files in Git** | Version-controlled, reviewable in PRs |
| **Use `helm lint`** | Catches template errors before deploy |
| **Set `--atomic` for prod deploys** | Auto-rollback if deploy fails |
| **Separate secrets from values** | Use external-secrets or sealed-secrets |

---

## Test Your Understanding 🧪

1. **What problem does Helm solve?**
2. **What's the difference between a Chart and a Release?**
3. **How do you deploy the same app to dev, staging, and prod?**
4. **How do you rollback a bad Helm deployment?**
5. **Why should you use `helm template` before deploying?**

<details>
<summary>Click to see answers</summary>

1. Helm solves YAML sprawl — managing dozens of K8s YAML files across environments. It templates your YAML, lets you customize via values files, and packages everything as a reusable chart.

2. A **Chart** is a package/template (like an npm package). A **Release** is a running instance of that chart (like a running app installed from that package). One chart can have many releases.

3. Use the same chart with different values files: `helm install app ./chart -f values-dev.yaml`, `helm install app ./chart -f values-prod.yaml`. Same templates, different configuration.

4. `helm rollback <release-name> <revision-number>`. Use `helm history <release-name>` to see available revisions.

5. `helm template` renders the final YAML locally without deploying. It lets you verify the output looks correct, catch errors, and review what will be applied to the cluster.

</details>

---

## What's Next?

➡️ **[11 — Monitoring & Logging](./11-monitoring-logging.md)** — See what's happening inside your cluster
