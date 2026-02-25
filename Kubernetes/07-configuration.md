# 07 — Configuration

## The Problem: Hardcoded Config

```text
Imagine your app has:
  - Database URL: postgres://db.prod:5432
  - API key: sk-abc123
  - Log level: debug

BAD approach — hardcode in the container image:
  ❌ Must rebuild the image to change ANY setting
  ❌ Different images for dev/staging/prod
  ❌ Secrets baked into image layers (security disaster)

GOOD approach — inject config at runtime:
  ✅ Same image everywhere (dev, staging, prod)
  ✅ Change config without rebuilding
  ✅ Secrets stored securely, injected at deploy time

  ┌──────────────────────────────────────────────────────────┐
  │                    SAME IMAGE                            │
  │                  my-app:1.0                              │
  │                                                          │
  │  Dev:     + ConfigMap(DB_URL=localhost)                  │
  │  Staging: + ConfigMap(DB_URL=staging-db)                 │
  │  Prod:    + ConfigMap(DB_URL=prod-db) + Secret(API_KEY)  │
  └──────────────────────────────────────────────────────────┘
```

---

## Three Ways to Configure Pods

| Method | What It Is | Best For |
|--------|-----------|----------|
| **Environment Variables** | Key-value pairs passed to container | Simple values (DB_HOST, LOG_LEVEL) |
| **ConfigMap** | K8s object storing non-sensitive config | Config files, feature flags, URLs |
| **Secret** | K8s object storing sensitive data | Passwords, API keys, TLS certs |

---

## 1. Environment Variables (Direct)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-demo
spec:
  containers:
    - name: app
      image: my-app:1.0
      env:
        - name: DATABASE_HOST
          value: "postgres.database.svc.cluster.local"
        - name: LOG_LEVEL
          value: "info"
        - name: APP_PORT
          value: "8080"
```

This works, but it's **not reusable**. If 10 Pods need the same config, you'd copy-paste it 10 times. Enter ConfigMaps.

---

## 2. ConfigMap — Non-Sensitive Configuration

```text
Think of it as: A SHARED DOCUMENT in Google Docs

  Instead of each person having their own copy (hardcoded env vars),
  everyone references the same document (ConfigMap).
  Update the document → everyone gets the new version.
```

### Create a ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Simple key-value pairs
  DATABASE_HOST: "postgres.database.svc.cluster.local"
  DATABASE_PORT: "5432"
  LOG_LEVEL: "info"
  FEATURE_NEW_UI: "true"

  # Entire config file
  nginx.conf: |
    server {
      listen 80;
      server_name myapp.com;
      location / {
        proxy_pass http://backend:8080;
      }
    }
```

### Use ConfigMap as Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-env-demo
spec:
  containers:
    - name: app
      image: my-app:1.0

      # Method 1: Pick specific keys
      env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_HOST

        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_PORT

      # Method 2: Load ALL keys as env vars
      envFrom:
        - configMapRef:
            name: app-config
```

### Use ConfigMap as a Mounted File

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-volume-demo
spec:
  volumes:
    - name: config-volume
      configMap:
        name: app-config

  containers:
    - name: nginx
      image: nginx:1.25
      volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d
          # nginx.conf from ConfigMap appears at
          # /etc/nginx/conf.d/nginx.conf
```

```text
Result inside the container:
  /etc/nginx/conf.d/
  ├── DATABASE_HOST      (contains: postgres.database...)
  ├── DATABASE_PORT      (contains: 5432)
  ├── LOG_LEVEL          (contains: info)
  ├── FEATURE_NEW_UI     (contains: true)
  └── nginx.conf         (contains: server { listen 80; ... })
```

### Create ConfigMap from CLI

```bash
# From literal values
kubectl create configmap my-config \
  --from-literal=DB_HOST=localhost \
  --from-literal=DB_PORT=5432

# From a file
kubectl create configmap nginx-config \
  --from-file=nginx.conf

# From a directory (each file becomes a key)
kubectl create configmap app-config \
  --from-file=config/
```

---

## 3. Secret — Sensitive Data

```text
Think of it as: A LOCKED SAFE vs. a bulletin board

  ConfigMap = Bulletin board (everyone can read)
  Secret    = Locked safe (restricted access, encoded)

  ⚠️ IMPORTANT: K8s Secrets are base64 ENCODED, not ENCRYPTED by default.
     base64 is NOT security — it's just encoding (easily decoded).
     For real security, enable encryption at rest in etcd.
```

### Create a Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  # Values MUST be base64 encoded
  username: YWRtaW4=           # echo -n "admin" | base64
  password: cGFzc3dvcmQxMjM=   # echo -n "password123" | base64

---
# OR use stringData (plain text — K8s encodes for you)
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin              # Plain text — K8s converts to base64
  password: password123
```

### Use Secret as Environment Variables

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-demo
spec:
  containers:
    - name: app
      image: my-app:1.0

      env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username

        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password

      # OR load all secret keys as env vars
      envFrom:
        - secretRef:
            name: db-credentials
```

### Use Secret as Mounted Files

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-demo
spec:
  volumes:
    - name: tls-certs
      secret:
        secretName: tls-secret
        defaultMode: 0400       # Read-only for owner

  containers:
    - name: app
      image: my-app:1.0
      volumeMounts:
        - name: tls-certs
          mountPath: /etc/tls
          readOnly: true
```

### Secret Types

| Type | Purpose |
|------|---------|
| `Opaque` | Generic key-value (default) |
| `kubernetes.io/tls` | TLS certificate + key |
| `kubernetes.io/dockerconfigjson` | Docker registry credentials |
| `kubernetes.io/basic-auth` | Username + password |
| `kubernetes.io/ssh-auth` | SSH private key |

### Create Secrets from CLI

```bash
# From literal values
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=s3cur3

# TLS secret from cert files
kubectl create secret tls my-tls \
  --cert=tls.crt \
  --key=tls.key

# Docker registry credentials
kubectl create secret docker-registry my-registry \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass
```

---

## ConfigMap vs. Secret — When to Use Which

```text
Is the data sensitive?
├── YES (passwords, API keys, tokens, certs)
│   └── Secret ✅
│
└── NO (URLs, ports, feature flags, config files)
    └── ConfigMap ✅
```

| Feature | ConfigMap | Secret |
|---------|----------|--------|
| **Data type** | Non-sensitive | Sensitive |
| **Encoding** | Plain text | Base64 encoded |
| **Size limit** | 1 MiB | 1 MiB |
| **RBAC** | Standard | Can restrict access separately |
| **Encryption at rest** | No | Optional (enable in etcd) |
| **Examples** | DB host, log level, nginx.conf | DB password, API key, TLS cert |

---

## Practical Example: Full Application Config

```yaml
# ConfigMap for non-sensitive config
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
data:
  DATABASE_HOST: "postgres.database.svc.cluster.local"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "myapp"
  REDIS_HOST: "redis.cache.svc.cluster.local"
  LOG_LEVEL: "info"
  ENABLE_CACHE: "true"

---
# Secret for sensitive data
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
type: Opaque
stringData:
  DATABASE_PASSWORD: "super-secret-password"
  JWT_SECRET: "my-jwt-signing-key-here"
  STRIPE_API_KEY: "sk_live_abc123"

---
# Deployment using both
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: app
          image: webapp:2.0
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: webapp-config    # All ConfigMap keys as env vars
            - secretRef:
                name: webapp-secrets   # All Secret keys as env vars
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
```

---

## Hot Reloading — Config Updates Without Restarts

```text
Mounted as Volume:
  ConfigMap/Secret changes → file updates automatically (within ~1 min)
  ✅ App can watch the file and reload

Injected as Env Var:
  ConfigMap/Secret changes → Pod does NOT see the change
  ❌ Must restart the Pod to pick up new values
  
  Restart all pods in a deployment:
  kubectl rollout restart deployment/webapp
```

---

## Security Best Practices for Secrets

| Practice | Why |
|----------|-----|
| **Enable encryption at rest** | base64 is NOT encryption — enable etcd encryption |
| **Use RBAC to restrict access** | Not everyone should `kubectl get secrets` |
| **Don't commit Secrets to Git** | Use sealed-secrets, SOPS, or external secret managers |
| **Use external secret managers** | AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager |
| **Rotate secrets regularly** | Minimize blast radius if leaked |
| **Mount as files, not env vars** | Env vars show up in `kubectl describe` and process listings |
| **Set `readOnly: true`** on volume mounts | Prevent containers from modifying secrets |

### External Secret Managers (Production Recommendation)

```text
Instead of storing secrets in K8s:

  ┌──────────┐     ┌────────────────────┐     ┌──────────────────┐
  │ External │     │ External Secrets   │     │ K8s Secret       │
  │ Vault    │ ──→ │ Operator           │ ──→ │ (auto-created)   │
  │          │     │ (syncs secrets)    │     │                  │
  └──────────┘     └────────────────────┘     └──────────────────┘

  Tools:
  • External Secrets Operator (ESO) — most popular
  • Sealed Secrets — encrypted in Git, decrypted in cluster
  • HashiCorp Vault + Vault Agent Injector
```

---

## Test Your Understanding 🧪

1. **Why should you never hardcode config in container images?**
2. **What's the difference between ConfigMap and Secret?**
3. **Are Kubernetes Secrets encrypted by default?**
4. **What happens when you update a ConfigMap — do Pods see it immediately?**
5. **Why is mounting secrets as files better than env vars?**

<details>
<summary>Click to see answers</summary>

1. You'd need different images for each environment (dev/staging/prod) and must rebuild just to change a URL. Also, secrets in images get stored in image layers — a security disaster.

2. ConfigMap stores non-sensitive data (URLs, feature flags). Secret stores sensitive data (passwords, API keys). Secrets are base64-encoded and can have stricter RBAC.

3. **NO.** They're base64 ENCODED, which is trivially decodable. You must explicitly enable encryption at rest in etcd for real security.

4. **If mounted as a volume** — the file updates automatically within ~60 seconds. **If injected as an env var** — the Pod does NOT see the change until restarted.

5. Environment variables are visible in `kubectl describe pod` output and in `/proc/PID/environ` inside the container. Mounted files can have restrictive permissions (0400) and don't leak into process metadata.

</details>

---

## What's Next?

➡️ **[08 — RBAC & Security](./08-rbac-security.md)** — Who can do what in your cluster
