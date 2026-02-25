# 01 — What Is Kubernetes?

## The Problem Kubernetes Solves

Before we talk about Kubernetes, let's understand the **problem it was built to solve**.

### The Old Way (Without Containers)

```text
Imagine you run a restaurant:

  🏠 One Big Kitchen (= One Physical Server)
  ├── Chef 1 makes Italian food    (App 1)
  ├── Chef 2 makes Japanese food   (App 2)
  └── Chef 3 makes Mexican food    (App 3)

Problems:
  ❌ If Chef 1 uses ALL the gas burners → Chef 2 and 3 can't cook
  ❌ If the kitchen catches fire → ALL food stops
  ❌ If you need 10x more Italian food → you can't just add Italian capacity
  ❌ Each chef needs different ingredients → conflicts and mess
```

This is what running multiple apps on **one physical server** looked like. Apps competed for CPU, memory, and disk. One bad app could crash everything.

### The Container Way

```text
Now imagine each chef gets their own portable food truck:

  🚚 Food Truck 1 — Italian (Container 1)
  🚚 Food Truck 2 — Japanese (Container 2)
  🚚 Food Truck 3 — Mexican  (Container 3)

Benefits:
  ✅ Each truck has its own stove, fridge, ingredients (isolated)
  ✅ If one truck breaks → others keep serving
  ✅ Need more Italian? → just add more Italian trucks
  ✅ Each truck can be parked anywhere (portable)
```

**Containers** = lightweight, portable, isolated boxes that run your application with everything it needs.

**Docker** is the tool that builds and runs these containers.

### But Wait — Who Manages 100 Food Trucks?

```text
You now have 100 food trucks across 5 cities:

  ❓ Which truck goes to which city?
  ❓ A truck broke down — who sends a replacement?
  ❓ Friday night rush — how do you add more trucks automatically?
  ❓ How do customers find the right truck?
  ❓ How do you update the menu without closing all trucks?

You need a MANAGER — someone to orchestrate all these trucks.

That manager is Kubernetes. 🎯
```

---

## So What IS Kubernetes?

**Kubernetes (K8s)** is a **container orchestration platform**. It manages your containers so you don't have to.

> **One-liner:** Kubernetes tells containers WHERE to run, WHEN to restart, HOW to scale, and WHO can access them.

The name comes from Greek: **κυβερνήτης** = "helmsman" or "pilot" (the person steering a ship).

**K8s** = K + 8 letters + s (because engineers are lazy typists 😄).

---

## What Kubernetes Does — The 7 Superpowers

| # | Superpower | What It Means | Real-World Analogy |
|---|-----------|---------------|-------------------|
| 1 | **Scheduling** | Decides which machine runs which container | Airport assigns gates to planes |
| 2 | **Self-Healing** | Automatically restarts crashed containers | Hospital ICU monitors — alarm goes off, nurse responds |
| 3 | **Scaling** | Adds/removes containers based on traffic | Uber adds more drivers during rush hour |
| 4 | **Load Balancing** | Distributes traffic across containers | Bank opens more counters when queue is long |
| 5 | **Rolling Updates** | Updates app with zero downtime | Replacing airplane engines mid-flight (one at a time) |
| 6 | **Service Discovery** | Containers find each other by name | Phone book — look up "database" and get its address |
| 7 | **Secret Management** | Safely stores passwords, API keys | Safety deposit box in a bank vault |

---

## Kubernetes vs. Docker — They're NOT Competitors

This confuses everyone. Let me clear it up:

```text
Docker = The tool that BUILDS and RUNS a single container
         (Think: a single food truck)

Kubernetes = The system that MANAGES hundreds of containers
             (Think: the fleet management company)

They work TOGETHER:
  Docker builds the container image → Kubernetes runs it at scale

Analogy:
  Docker    = A car
  Kubernetes = The entire highway system (roads, traffic lights, GPS, toll booths)
  
  You need cars (Docker) to drive on highways (Kubernetes).
  But highways don't build cars, and cars don't build highways.
```

| Feature | Docker | Kubernetes |
|---------|--------|-----------|
| Build container images | ✅ | ❌ |
| Run a single container | ✅ | ✅ (but overkill) |
| Run 100+ containers across machines | ❌ (manual) | ✅ |
| Auto-restart crashed containers | ❌ | ✅ |
| Auto-scale based on load | ❌ | ✅ |
| Load balance traffic | ❌ | ✅ |
| Rolling updates | ❌ | ✅ |
| Manage secrets | ❌ | ✅ |

---

## When to Use Kubernetes (And When NOT To)

### ✅ Use Kubernetes When:

- You have **multiple services** (microservices architecture)
- You need **auto-scaling** (traffic varies a lot)
- You need **zero-downtime deployments**
- You run on **multiple servers** (not just one laptop)
- You need **high availability** (app must stay up 24/7)
- Your team deploys **frequently** (multiple times per day)

### ❌ Don't Use Kubernetes When:

- You have **one simple app** on **one server** (use Docker Compose instead)
- Your team is **< 3 engineers** and you don't have ops knowledge
- You're building a **prototype** (too much setup overhead)
- Your app has **very low traffic** and doesn't need scaling
- You're not using containers at all

### Decision Tree

```text
Do I have containers?
├── NO → Start with Docker first, then come back
└── YES
    ├── Just 1-3 containers on one machine?
    │   └── Use Docker Compose ✅ (simpler)
    ├── Multiple containers across multiple machines?
    │   └── Use Kubernetes ✅
    └── Need auto-scaling, self-healing, zero-downtime deploys?
        └── Kubernetes is your answer ✅
```

---

## Key Terminology — The Words You'll Hear Everywhere

| Term | What It Means | Analogy |
|------|--------------|---------|
| **Cluster** | A group of machines running Kubernetes | A fleet of trucks managed by one company |
| **Node** | A single machine (physical or virtual) in the cluster | One truck in the fleet |
| **Pod** | The smallest deployable unit (usually 1 container) | One food order being prepared |
| **Deployment** | A blueprint that says "run 3 copies of this Pod" | An order to the fleet: "send 3 Italian trucks" |
| **Service** | A stable address to reach your Pods | A phone number that always works, no matter which truck answers |
| **Namespace** | A virtual partition within a cluster | Different departments in a company |
| **kubectl** | The CLI tool to talk to Kubernetes | Your walkie-talkie to the fleet manager |
| **Container Image** | A packaged app ready to run | A recipe + all ingredients, vacuum-sealed |
| **Registry** | Where container images are stored | A warehouse full of vacuum-sealed recipe kits |

---

## How Kubernetes Works — The 30-Second Version

```text
  YOU (Developer)
    │
    │  "Hey K8s, I want 3 copies of my web app running"
    │
    ▼
┌─────────────────────────────────────────────────────┐
│              KUBERNETES CONTROL PLANE                │
│         (The brain / fleet management HQ)            │
│                                                     │
│  1. Receives your request                           │
│  2. Decides WHICH nodes should run the containers   │
│  3. Tells those nodes to start the containers       │
│  4. Continuously watches: are all 3 still healthy?  │
│  5. If one dies → automatically starts a new one    │
└────────────┬────────────────────┬───────────────────┘
             │                    │
             ▼                    ▼
     ┌──────────────┐    ┌──────────────┐
     │   NODE 1     │    │   NODE 2     │
     │  (Machine)   │    │  (Machine)   │
     │              │    │              │
     │  ┌────────┐  │    │  ┌────────┐  │
     │  │ Pod 1  │  │    │  │ Pod 3  │  │
     │  │ (App)  │  │    │  │ (App)  │  │
     │  └────────┘  │    │  └────────┘  │
     │  ┌────────┐  │    │              │
     │  │ Pod 2  │  │    │              │
     │  │ (App)  │  │    │              │
     │  └────────┘  │    │              │
     └──────────────┘    └──────────────┘
```

---

## Your First Kubernetes Commands

Once you have `minikube` and `kubectl` installed:

```bash
# 1. Start a local cluster
minikube start

# 2. Check your cluster is running
kubectl cluster-info

# 3. See your nodes (should show 1 node — minikube)
kubectl get nodes

# 4. Run your first app!
kubectl create deployment hello --image=nginx

# 5. See your deployment
kubectl get deployments

# 6. See the pod it created
kubectl get pods

# 7. Expose it so you can access it
kubectl expose deployment hello --port=80 --type=NodePort

# 8. Open it in your browser
minikube service hello

# 9. Clean up
kubectl delete deployment hello
kubectl delete service hello
```

### What Just Happened?

```text
Step 4: You told K8s "I want an nginx web server running"
        K8s created a Deployment → which created a ReplicaSet → which created a Pod

Step 7: You told K8s "Let people access this app on port 80"
        K8s created a Service that routes traffic to your Pod

Step 8: minikube opened a browser pointing to your running nginx!

  YOU ──→ Service (port) ──→ Pod ──→ nginx container ──→ "Welcome to nginx!" page
```

---

## Test Your Understanding 🧪

Try answering these before moving to the next module:

1. **What problem does Kubernetes solve that Docker alone can't?**
2. **What's the difference between a Pod and a Container?**
3. **If a container crashes, what does Kubernetes do automatically?**
4. **Name 3 situations where you should NOT use Kubernetes.**
5. **What command shows you all running Pods?**

<details>
<summary>Click to see answers</summary>

1. Docker runs containers on a single machine. Kubernetes manages containers across MULTIPLE machines — handling scheduling, scaling, self-healing, load balancing, and rolling updates.

2. A Pod is a wrapper around one or more containers. It's the smallest unit Kubernetes manages. A container is the actual running process inside the Pod. Most Pods have exactly one container.

3. Kubernetes detects the crash and automatically starts a new container to replace it (self-healing).

4. (Any 3): Single simple app, very small team with no ops, prototype/MVP, very low traffic, not using containers.

5. `kubectl get pods`

</details>

---

## What's Next?

➡️ **[02 — Architecture](./02-architecture.md)** — How Kubernetes is built internally (the control plane, nodes, and all the components)
