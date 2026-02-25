# 06 — Storage

## The Problem: Containers Are Ephemeral

```text
Imagine you're writing a diary on a whiteboard.
Every time the janitor cleans the room (container restart),
your diary is ERASED. 😱

  Container starts  →  writes data to /data  →  crashes  →  restarts
                                                              │
                                                    /data is EMPTY again!

  This is a problem for:
  ❌ Databases (data is gone!)
  ❌ File uploads (user photos vanish!)
  ❌ Logs (debugging impossible!)

  SOLUTION: Attach a VOLUME — an external storage that survives restarts.

  It's like writing your diary in a notebook (volume) instead
  of a whiteboard (container filesystem). The notebook stays
  even if you change rooms.
```

---

## Storage Concepts — The Three Layers

```text
  ┌───────────────────────────────────────────────────────────────┐
  │                     HOW STORAGE WORKS IN K8s                  │
  │                                                               │
  │   Pod YAML says:                                              │
  │   "I need 10Gi of storage"                                    │
  │         │                                                     │
  │         ▼                                                     │
  │   ┌──────────────────┐   ┌──────────────────┐                 │
  │   │ PersistentVolume │   │ PersistentVolume │                 │
  │   │ Claim (PVC)      │   │ (PV)             │                 │
  │   │                  │──→│                  │                 │
  │   │ "I WANT 10Gi"    │   │ "I HAVE 10Gi"    │                 │
  │   │ (Request)        │   │ (Actual disk)     │                 │
  │   └──────────────────┘   └──────────────────┘                 │
  │                                   │                           │
  │                                   ▼                           │
  │                          ┌──────────────────┐                 │
  │                          │ Actual Storage   │                 │
  │                          │ (EBS, NFS, local │                 │
  │                          │  disk, GCE PD)   │                 │
  │                          └──────────────────┘                 │
  │                                                               │
  │   Analogy:                                                    │
  │   PVC = Apartment rental application ("I need a 2-bedroom")  │
  │   PV  = The actual apartment                                  │
  │   StorageClass = The real estate agency (auto-provisions)     │
  └───────────────────────────────────────────────────────────────┘
```

| Concept | What It Is | Who Creates It |
|---------|-----------|----------------|
| **Volume** | Storage attached to a Pod | Defined in Pod spec |
| **PersistentVolume (PV)** | A piece of storage in the cluster | Admin or StorageClass (auto) |
| **PersistentVolumeClaim (PVC)** | A request for storage by a Pod | Developer (you) |
| **StorageClass** | Template for auto-provisioning PVs | Admin (one-time setup) |

---

## Volume Types — Start Simple

### emptyDir — Temporary Shared Storage

```text
  Lives as long as the Pod.
  Perfect for sharing data BETWEEN containers in the same Pod.
  Deleted when Pod is removed.

  ┌────────────────────────────────────┐
  │              POD                    │
  │                                    │
  │  ┌──────────┐   ┌──────────────┐  │
  │  │Container │   │Container     │  │
  │  │ (App)    │   │ (Log Shipper)│  │
  │  │          │   │              │  │
  │  │ writes → │   │ ← reads     │  │
  │  └────┬─────┘   └─────┬───────┘  │
  │       │               │          │
  │  ┌────▼───────────────▼────┐     │
  │  │    emptyDir volume      │     │
  │  │    /var/log/app         │     │
  │  └─────────────────────────┘     │
  │                                    │
  │  ⚠️ Deleted when Pod dies          │
  └────────────────────────────────────┘
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-demo
spec:
  volumes:
    - name: shared-data
      emptyDir: {}

  containers:
    - name: app
      image: my-app:1.0
      volumeMounts:
        - name: shared-data
          mountPath: /var/log/app

    - name: log-shipper
      image: fluentd:latest
      volumeMounts:
        - name: shared-data
          mountPath: /var/log/app
          readOnly: true
```

### hostPath — Node's Filesystem

```text
  Mounts a directory from the NODE's filesystem into the Pod.
  
  ⚠️ DANGER: If Pod moves to a different node, data is lost!
  ⚠️ Use only for DaemonSets (which run on every node anyway).
```

```yaml
volumes:
  - name: node-logs
    hostPath:
      path: /var/log
      type: Directory
```

---

## PersistentVolume (PV) and PersistentVolumeClaim (PVC)

### The Full Picture

```text
  Step 1: Admin creates a PersistentVolume (or StorageClass auto-creates it)
  Step 2: Developer creates a PersistentVolumeClaim (request)
  Step 3: K8s matches PVC to PV (binding)
  Step 4: Pod uses the PVC as a volume

  ┌─────────────────────────────────────────────────────────────────┐
  │                                                                 │
  │  ADMIN creates:                  DEVELOPER creates:             │
  │                                                                 │
  │  ┌───────────────────┐          ┌───────────────────┐           │
  │  │ PersistentVolume  │          │ PersistentVolume  │           │
  │  │                   │◄─────────│ Claim             │           │
  │  │ capacity: 20Gi    │  bind    │                   │           │
  │  │ accessModes: RWO  │          │ request: 10Gi     │           │
  │  │ storageClass: ssd │          │ accessModes: RWO  │           │
  │  │ source: AWS EBS   │          │ storageClass: ssd │           │
  │  └───────────────────┘          └────────┬──────────┘           │
  │                                          │                      │
  │                                     ┌────▼─────┐                │
  │                                     │   Pod    │                │
  │                                     │          │                │
  │                                     │ volume:  │                │
  │                                     │   pvc:   │                │
  │                                     │    name  │                │
  │                                     └──────────┘                │
  └─────────────────────────────────────────────────────────────────┘
```

### Access Modes

| Mode | Abbreviation | What It Means |
|------|-------------|---------------|
| **ReadWriteOnce** | RWO | One node can read/write (most common) |
| **ReadOnlyMany** | ROX | Many nodes can read (shared config) |
| **ReadWriteMany** | RWX | Many nodes can read/write (NFS, EFS) |

### Reclaim Policies

| Policy | What Happens When PVC Is Deleted |
|--------|--------------------------------|
| **Retain** | PV stays, data preserved (manual cleanup) |
| **Delete** | PV and underlying storage are deleted |
| **Recycle** | Data wiped, PV made available again (deprecated) |

### Manual PV + PVC Example

```yaml
# Step 1: PersistentVolume (Admin creates this)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:                      # For demo only — use cloud storage in prod!
    path: /mnt/data

---
# Step 2: PersistentVolumeClaim (Developer creates this)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi              # Requesting 10Gi from the 20Gi PV
  storageClassName: manual

---
# Step 3: Pod uses the PVC
apiVersion: v1
kind: Pod
metadata:
  name: storage-demo
spec:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-pvc        # Reference the PVC

  containers:
    - name: app
      image: my-app:1.0
      volumeMounts:
        - name: data
          mountPath: /app/data   # Data persists here across restarts!
```

---

## StorageClass — Automatic Provisioning

```text
Manual PV creation = tedious. You'd need to pre-create PVs for every request.

StorageClass = AUTOMATIC. Developer creates a PVC, StorageClass
               automatically provisions the right PV.

  Without StorageClass:
    Admin creates 50 PVs manually → Developers claim them
    ❌ Slow, doesn't scale

  With StorageClass:
    Developer creates PVC → StorageClass auto-creates PV on demand
    ✅ Self-service, scales infinitely
```

```yaml
# StorageClass (Admin creates once)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com   # AWS EBS CSI driver
parameters:
  type: gp3                     # SSD storage type
  iopsPerGB: "3000"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true      # Allow resizing later
```

```yaml
# PVC (Developer creates — PV is auto-provisioned!)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd    # Use the StorageClass above
  resources:
    requests:
      storage: 50Gi
```

### Common StorageClass Providers

| Cloud | Provisioner | Storage Type |
|-------|-----------|-------------|
| **AWS** | `ebs.csi.aws.com` | EBS (gp3, io2) |
| **AWS** | `efs.csi.aws.com` | EFS (shared NFS) |
| **GCP** | `pd.csi.storage.gke.io` | Persistent Disk |
| **Azure** | `disk.csi.azure.com` | Managed Disk |
| **Local** | `rancher.io/local-path` | Local disk (dev only) |

---

## Storage Decision Tree

```text
What kind of data am I storing?

├── Temporary data shared between containers in same Pod?
│   └── emptyDir ✅
│
├── Data that must survive Pod restarts?
│   ├── Single Pod reads/writes?
│   │   └── PVC with RWO (ReadWriteOnce) ✅
│   │       e.g., database data directory
│   │
│   └── Multiple Pods need to read/write the SAME data?
│       └── PVC with RWX (ReadWriteMany) ✅
│           e.g., shared file uploads (use EFS/NFS)
│
├── Configuration files?
│   └── ConfigMap or Secret mounted as volume ✅
│       (see 07-configuration.md)
│
└── Node-level system data (logs, metrics)?
    └── hostPath in a DaemonSet ✅
```

---

## Production Best Practices

| Practice | Why |
|----------|-----|
| **Always use StorageClass** | Manual PV management doesn't scale |
| **Set `reclaimPolicy: Retain` for databases** | Prevents accidental data loss |
| **Use `volumeBindingMode: WaitForFirstConsumer`** | Ensures PV is in the same zone as the Pod |
| **Enable `allowVolumeExpansion: true`** | Lets you resize storage without recreating |
| **Use CSI drivers, not in-tree** | In-tree provisioners are deprecated |
| **Back up PVs regularly** | K8s doesn't do backups — use Velero or cloud snapshots |
| **Don't use hostPath in production** | Data is node-specific and not replicated |

---

## Common kubectl Commands for Storage

```bash
# List PersistentVolumes
kubectl get pv

# List PersistentVolumeClaims
kubectl get pvc

# List StorageClasses
kubectl get sc

# Describe a PVC (see binding status)
kubectl describe pvc my-pvc

# Check which PV a PVC is bound to
kubectl get pvc my-pvc -o jsonpath='{.spec.volumeName}'

# Resize a PVC (if StorageClass allows it)
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

---

## Test Your Understanding 🧪

1. **What happens to data in a container when it restarts (without volumes)?**
2. **What's the difference between a PV and a PVC?**
3. **When would you use `ReadWriteMany` vs. `ReadWriteOnce`?**
4. **Why should you avoid `hostPath` in production?**
5. **What does a StorageClass do?**
6. **What's the safest reclaim policy for a production database?**

<details>
<summary>Click to see answers</summary>

1. All data is LOST. Container filesystems are ephemeral — they start fresh on every restart.

2. **PV** = the actual storage resource (the apartment). **PVC** = a request for storage (the rental application). PVCs get matched/bound to PVs.

3. **RWO** (ReadWriteOnce) = one node can mount it for read/write. Use for databases and single-instance apps. **RWX** (ReadWriteMany) = multiple nodes can mount simultaneously. Use for shared storage like file uploads accessed by multiple Pods.

4. hostPath ties data to a specific node. If the Pod moves to a different node, the data is gone. Also, Pods can access sensitive host files — security risk.

5. A StorageClass automatically provisions PersistentVolumes on demand. Instead of admins manually creating PVs, the StorageClass creates them when a PVC is submitted.

6. **Retain** — when the PVC is deleted, the PV and its data are preserved. You can manually recover the data. `Delete` would destroy the disk automatically.

</details>

---

## What's Next?

➡️ **[07 — Configuration](./07-configuration.md)** — ConfigMaps, Secrets, and environment variables
