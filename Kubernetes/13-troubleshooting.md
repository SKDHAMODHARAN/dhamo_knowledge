# 13 — Troubleshooting

## The Debugging Mindset

```text
When something breaks in Kubernetes, follow this SYSTEMATIC approach:

  ┌──────────────────────────────────────────────────────────────┐
  │                 DEBUGGING FLOWCHART                          │
  │                                                              │
  │  1. WHAT is the symptom?                                     │
  │     Pod not starting? App returning errors? Can't connect?   │
  │                                                              │
  │  2. WHERE is the problem?                                    │
  │     Pod level? Service level? Node level? Cluster level?     │
  │                                                              │
  │  3. GATHER evidence                                          │
  │     kubectl describe, kubectl logs, kubectl get events       │
  │                                                              │
  │  4. NARROW DOWN the root cause                               │
  │     Is it config? Resources? Networking? Image? Permissions? │
  │                                                              │
  │  5. FIX and VERIFY                                           │
  │     Apply fix, watch for recovery                            │
  └──────────────────────────────────────────────────────────────┘
```

---

## Debugging Decision Tree

```text
My app isn't working. What do I check?

├── Pod won't START (stuck in Pending/CrashLoopBackOff/ImagePullBackOff)
│   └── Jump to: "Pod Not Starting" section below
│
├── Pod is RUNNING but app returns ERRORS
│   └── Jump to: "App Errors" section below
│
├── Pod is running but I CAN'T CONNECT to it
│   └── Jump to: "Networking Issues" section below
│
├── Pod was running but got KILLED/EVICTED
│   └── Jump to: "Pod Killed" section below
│
└── Everything seems fine but PERFORMANCE IS BAD
    └── Jump to: "Performance Issues" section below
```

---

## Pod Not Starting

### Status: Pending

```text
Pod is stuck in "Pending" — Scheduler can't find a node for it.
```

```bash
# Step 1: Check why it's pending
kubectl describe pod <pod-name>

# Look at the Events section at the bottom for messages like:
# "0/3 nodes are available: 3 Insufficient cpu"
# "0/3 nodes are available: 3 Insufficient memory"
# "0/3 nodes are available: 3 node(s) had taint..."
```

| Event Message | Cause | Fix |
|--------------|-------|-----|
| `Insufficient cpu` | No node has enough CPU | Reduce requests, add nodes, or delete unneeded Pods |
| `Insufficient memory` | No node has enough memory | Same as above |
| `node(s) had taint` | Node is tainted, Pod doesn't tolerate it | Add toleration to Pod or untaint node |
| `no persistent volumes available` | PVC can't bind to a PV | Create PV or fix StorageClass |
| `didn't match pod anti-affinity rules` | Anti-affinity can't be satisfied | Relax anti-affinity or add more nodes |

### Status: ImagePullBackOff / ErrImagePull

```text
K8s can't download the container image.
```

```bash
kubectl describe pod <pod-name>
# Look for: "Failed to pull image..."
```

| Cause | Fix |
|-------|-----|
| Image name typo | Check `image:` field for typos |
| Tag doesn't exist | Verify the tag exists in the registry |
| Private registry, no credentials | Create `imagePullSecrets` |
| Registry is down | Check registry status |
| Network policy blocking egress | Allow egress to registry |

```bash
# Test if you can pull the image manually
docker pull <image-name>:<tag>

# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass
```

### Status: CrashLoopBackOff

```text
Container starts, crashes, restarts, crashes, restarts...
K8s keeps restarting it with increasing delays (10s, 20s, 40s...).
```

```bash
# Step 1: Check the logs (what did it print before crashing?)
kubectl logs <pod-name>

# Step 2: Check previous crash logs
kubectl logs <pod-name> --previous

# Step 3: Check the exit code
kubectl describe pod <pod-name>
# Look for: "Last State: Terminated" → "Exit Code: 1"
```

| Exit Code | Meaning | Common Cause |
|-----------|---------|-------------|
| 0 | Success (but shouldn't exit) | Process finished — doesn't run as daemon |
| 1 | General error | App crash, missing config, bad code |
| 126 | Permission denied | Can't execute the command |
| 127 | Command not found | Wrong `command:` in Pod spec |
| 137 | OOMKilled (128 + 9) | Container exceeded memory limit |
| 139 | Segfault (128 + 11) | Application bug |
| 143 | SIGTERM (128 + 15) | Graceful shutdown signal |

```bash
# Common fixes:
# 1. Check if the image runs standalone
docker run -it <image>:<tag>

# 2. Start a debug container
kubectl debug -it <pod-name> --image=busybox -- sh

# 3. Override the command to keep the container alive
kubectl run debug --image=<image>:<tag> --command -- sleep infinity
kubectl exec -it debug -- sh
```

### Status: CreateContainerConfigError

```text
Container can't be created due to config issues.
```

```bash
kubectl describe pod <pod-name>
# Look for: "Error: configmap 'x' not found" or "secret 'x' not found"
```

| Cause | Fix |
|-------|-----|
| Referenced ConfigMap doesn't exist | Create the ConfigMap first |
| Referenced Secret doesn't exist | Create the Secret first |
| Volume mount path conflict | Check volumeMounts for conflicts |

---

## App Returns Errors

```bash
# Step 1: Check application logs
kubectl logs <pod-name>
kubectl logs <pod-name> -f  # Stream in real-time

# Step 2: Exec into the container and investigate
kubectl exec -it <pod-name> -- sh

# Step 3: Check environment variables
kubectl exec <pod-name> -- env

# Step 4: Check if the app can reach its dependencies
kubectl exec <pod-name> -- nslookup database-service
kubectl exec <pod-name> -- curl -v http://backend-service:8080/health

# Step 5: Check events for the namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

---

## Networking Issues

### Can't Reach the Service

```bash
# Step 1: Is the Service defined correctly?
kubectl get svc <service-name>
kubectl describe svc <service-name>

# Step 2: Does the Service have endpoints (Pod IPs)?
kubectl get endpoints <service-name>
# If EMPTY → selector doesn't match any Pod labels!

# Step 3: Test DNS from inside the cluster
kubectl run -it --rm debug --image=busybox -- nslookup <service-name>

# Step 4: Test connectivity from inside the cluster
kubectl run -it --rm debug --image=curlimages/curl -- curl http://<service-name>:<port>

# Step 5: Check NetworkPolicies
kubectl get networkpolicies -n <namespace>
```

### Common Networking Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Service has no endpoints | Selector doesn't match Pod labels | Fix labels to match |
| DNS resolution fails | CoreDNS is down or misconfigured | Check `kubectl get pods -n kube-system` |
| Connection refused | Pod is running but app not listening on the right port | Check `containerPort` matches app port |
| Connection timeout | NetworkPolicy blocking traffic | Review NetworkPolicies |
| External traffic not reaching | Ingress misconfigured or no Ingress controller | Check `kubectl get ingress`, verify controller |

### Service Selector Mismatch (Most Common!)

```text
  Service:                    Pod:
  selector:                   labels:
    app: web-app                app: webapp     ← MISMATCH! "web-app" ≠ "webapp"

  FIX: Labels must EXACTLY match.
```

```bash
# Quick check: compare Service selector with Pod labels
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels
```

---

## Pod Killed / Evicted

### OOMKilled (Out of Memory)

```bash
kubectl describe pod <pod-name>
# Look for: "OOMKilled" in container status
```

```text
  Container used more memory than its limit.
  Fix: Increase memory limit, fix memory leak, or optimize app.

  Check current usage:
  kubectl top pod <pod-name>
```

### Evicted

```bash
kubectl get pods | grep Evicted
kubectl describe pod <evicted-pod>
# Look for: "The node was low on resource: memory"
```

```text
  Node ran out of resources (disk, memory).
  K8s evicts Pods to protect the node.

  Fix:
  - Add more nodes (Cluster Autoscaler)
  - Reduce resource requests
  - Clean up disk (images, logs)
  - Set proper resource limits
```

### Pod Killed During Node Drain

```bash
# Check if PDB is configured
kubectl get pdb

# Check if nodes are being drained
kubectl get nodes
# Look for: SchedulingDisabled status
```

---

## Performance Issues

```bash
# Check resource usage vs. requests/limits
kubectl top pods
kubectl top nodes

# Check HPA status (is it scaling?)
kubectl get hpa
kubectl describe hpa <hpa-name>

# Check for throttling (CPU limit hit)
# In Prometheus: container_cpu_cfs_throttled_seconds_total

# Check for slow dependencies
kubectl exec -it <pod-name> -- curl -w "@-" -o /dev/null -s http://dependency:port <<'EOF'
    time_namelookup:  %{time_namelookup}\n
    time_connect:     %{time_connect}\n
    time_starttransfer: %{time_starttransfer}\n
    time_total:       %{time_total}\n
EOF
```

---

## Essential Debug Commands Cheat Sheet

```bash
# ─── CLUSTER LEVEL ───
kubectl cluster-info                     # Is the cluster reachable?
kubectl get nodes                        # Node health
kubectl describe node <node>             # Node details, allocatable resources
kubectl top nodes                        # CPU/memory usage per node
kubectl get events --all-namespaces --sort-by='.lastTimestamp'  # Recent events

# ─── POD LEVEL ───
kubectl get pods -o wide                 # Pod status, IP, node
kubectl describe pod <pod>               # Detailed Pod info (MOST USEFUL!)
kubectl logs <pod>                       # Application logs
kubectl logs <pod> --previous            # Logs from last crash
kubectl logs <pod> -c <container>        # Logs from specific container
kubectl top pod <pod>                    # CPU/memory usage
kubectl exec -it <pod> -- sh            # Shell into container
kubectl debug -it <pod> --image=busybox  # Attach debug container

# ─── SERVICE/NETWORKING ───
kubectl get svc                          # List services
kubectl get endpoints <svc>              # Pod IPs behind a service
kubectl describe svc <svc>               # Service details
kubectl get ingress                      # Ingress rules
kubectl run -it --rm debug --image=busybox -- nslookup <svc>  # Test DNS

# ─── DEPLOYMENT ───
kubectl rollout status deployment/<name>  # Rollout progress
kubectl rollout history deployment/<name> # Rollout history
kubectl rollout undo deployment/<name>    # Emergency rollback

# ─── TROUBLESHOOTING ───
kubectl get events -n <ns> --sort-by='.lastTimestamp'  # Recent events
kubectl api-resources                    # List all resource types
kubectl explain <resource>               # Built-in docs for any resource
kubectl explain pod.spec.containers      # Deep-dive into spec fields
```

---

## Common Issues Quick Reference

| Symptom | First Command | Likely Cause |
|---------|--------------|-------------|
| Pod stuck `Pending` | `kubectl describe pod` | Insufficient resources or taints |
| Pod `CrashLoopBackOff` | `kubectl logs --previous` | App crash — check logs for error |
| Pod `ImagePullBackOff` | `kubectl describe pod` | Wrong image name/tag or auth |
| Pod `OOMKilled` | `kubectl describe pod` | Memory limit too low |
| Service returns 502/503 | `kubectl get endpoints` | No healthy Pods behind Service |
| Can't connect to Service | `kubectl get endpoints` | Selector mismatch or no Pods |
| Deployment stuck | `kubectl rollout status` | Readiness probe failing on new Pods |
| HPA not scaling | `kubectl describe hpa` | Missing metrics-server or no requests set |
| PVC stuck `Pending` | `kubectl describe pvc` | No matching PV or StorageClass |
| Node `NotReady` | `kubectl describe node` | Node unhealthy — kubelet/network issue |

---

## Debugging Mindset Tips

```text
  ┌──────────────────────────────────────────────────────────────┐
  │  DEBUGGING PRINCIPLES                                        │
  │                                                              │
  │  1. READ THE EVENTS                                          │
  │     kubectl describe <resource> → Events section             │
  │     90% of answers are here.                                 │
  │                                                              │
  │  2. READ THE LOGS                                            │
  │     kubectl logs <pod> --previous                            │
  │     The answer is almost always in the logs.                 │
  │                                                              │
  │  3. CHECK RECENT CHANGES                                     │
  │     "What changed?" is the fastest path to root cause.       │
  │     New deploy? New config? Node drain?                      │
  │                                                              │
  │  4. REPRODUCE LOCALLY                                        │
  │     kubectl exec -it <pod> -- sh                             │
  │     Run commands inside the container to test.               │
  │                                                              │
  │  5. DON'T GUESS — MEASURE                                    │
  │     kubectl top pods/nodes                                   │
  │     Check actual CPU/memory, not assumptions.                │
  │                                                              │
  │  6. CHECK THE SIMPLE STUFF FIRST                             │
  │     Typo in image name? Wrong namespace? Label mismatch?     │
  │     Most "mysterious" bugs are simple mistakes.              │
  └──────────────────────────────────────────────────────────────┘
```

---

## 🎓 Congratulations!

You've completed the entire Kubernetes learning path — from "What's a container?" to production-grade troubleshooting. Here's what you've learned:

```text
  ✅ Level 1: Foundations (What, Why, Architecture, Pods)
  ✅ Level 2: Core Workloads (Deployments, Services, Storage, Config)
  ✅ Level 3: Production Readiness (Security, Scaling, Helm, Monitoring)
  ✅ Level 4: Mastery (Best Practices, Troubleshooting)
```

### What's Next on Your Journey?

| Topic | Why | Resource |
|-------|-----|---------|
| **Service Mesh (Istio/Linkerd)** | Traffic management, mTLS, observability | [istio.io](https://istio.io) |
| **GitOps (ArgoCD/FluxCD)** | Git as source of truth for deployments | [argoproj.github.io](https://argoproj.github.io) |
| **Operators** | Automate complex app lifecycle management | [operatorhub.io](https://operatorhub.io) |
| **CKA/CKAD Certification** | Prove your Kubernetes skills | [kubernetes.io/training](https://kubernetes.io/training) |
| **Multi-Cluster Management** | Run workloads across clusters | [karmada.io](https://karmada.io) |
