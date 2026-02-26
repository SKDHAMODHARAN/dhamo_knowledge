# 🎯 Career Survival Guide — Platform/DevOps Engineer

> Written for: 2024 graduate, Associate level, doing Platform Engineering
> Goal: Financial stability + career growth through the AI era (next 10–15 years)

---

## 🔮 5–10 Year Prediction for Platform/DevOps

```
AI is replacing:     junior devs writing CRUD APIs, scripting, simple automation
AI is NOT replacing: infrastructure decisions, production incident response,
                     security ownership, system architecture, cost trade-offs
```

**Platform Engineering is GROWING because of AI** — more AI apps = more infrastructure needed.
The role shifts from *writing Terraform manually* → *owning and validating what AI generates*.

---

## ✅ Your Honest Situation (2024 Graduate)

| What feels like a weakness | The reality |
|---|---|
| Jumped between Data Eng → QA → DevOps | Valuable breadth — 3 stack layers in 2 years |
| Not confident in any skill | Means you haven't been fooled into false confidence |
| Fear about the AI era | Good — it means you're paying attention |

**You have 35+ years of career ahead. The engineers being laid off spent 10 years doing the exact same thing repeatedly. You haven't had time to make that mistake.**

---

## 🗺️ Your Exact Roadmap — Follow This

### Phase 1 — Foundation (Months 1–6)

```
Month 1–2: Terraform
  → Work through Terraform/ folder in this repo
  → Deploy a real VPC + EC2 + RDS in a free-tier AWS account
  → Break it and fix it 5 times
  ✓ Goal: "I can provision AWS infra from scratch without help"

Month 3–4: Kubernetes Deep Dive
  → Work through Kubernetes/ folder in this repo
  → Run minikube locally, deploy apps, break things intentionally
  ✓ Goal: "I understand why pods crash and how to fix them"

Month 5–6: CI/CD Ownership
  → Build a GitHub Actions pipeline that tests + deploys something real
  → Use your QA background — add automated tests to the pipeline
  ✓ Goal: "I can design a full deploy pipeline from scratch"
```

### Phase 2 — Get Known for One Thing (Months 7–12)

**Pick ONE and go deep. My recommendation: Observability** (you already work on OTEL at Genesys — double down on what you know.)

| Option | Why valuable | Demand |
|---|---|---|
| **Observability** (OTEL, Grafana, Prometheus) | You already work on this | Very High |
| Security / DevSecOps | Every company needs it, few have it | Extremely High |
| Cost Optimization | C-suite priority in every company | High |
| EKS / Kubernetes Operations | Cloud scale = K8s scale | High |

### Phase 3 — Career Security (Years 2–4)

```
→ Be the person your team comes to for one specific thing
→ Write runbooks and internal docs (teaching = mastery)
→ Speak in business impact: "Saved $3000/month" > "Optimized NAT gateway"
→ Build GitHub portfolio of real work (this repo is the start)
→ Raise your hand for harder problems — comfort is a red flag
```

---

## 💰 Financial Roadmap (India — Honest Estimates)

| Timeline | Level | Expected Range |
|---|---|---|
| Now | Associate Platform Eng | ₹6–10 LPA |
| 18 months | Mid-level | ₹12–18 LPA |
| 3 years | Senior | ₹20–30 LPA |
| 5 years | Staff / Lead | ₹35–50+ LPA |

> DevOps/Platform salaries are rising because supply is low and demand keeps growing.

---

## 🧠 Skills That Survive AI — Permanently

| Irreplaceable | Augmented by AI |
|---|---|
| System-level thinking | Terraform / IaC design |
| Business context (WHY before keyboard) | Kubernetes operations |
| Debugging under pressure | CI/CD pipeline design |
| Owning outcomes, not just tasks | Security architecture |
| Communicating trade-offs clearly | Cost optimization |

> **AI writes code. You own the decision behind the code. That's the shift.**

---

## ⚠️ What Can Derail You

```
❌ Learning 10 things at 10% depth — pick one and go to 80%
❌ Watching tutorials without building anything real
❌ Waiting to feel "ready" — you learn by doing, not preparing
❌ Staying comfortable — if work feels easy, ask for harder problems
❌ Comparing yourself to engineers 5 years ahead of you
```

---

## 🔁 The Learning Cycle That Actually Works

```
1. Read the concept (this repo)
2. Build it in real AWS (free tier)
3. Break it intentionally
4. Debug it yourself first — struggle is the learning
5. Document what you learned
6. Repeat
```

---

## 📅 Weekly Habit (Non-Negotiable)

```
Monday–Friday: 1 hour of deliberate learning (no multitasking, no YouTube)
Saturday:      Build something / deploy something real
Sunday:        Write one thing down — what did you learn this week?
```

---

## 💬 The Single Most Important Reminder

> Your biggest risk is NOT the AI era.
> It is spending the next 18 months being comfortable instead of uncomfortable.

**Every week you don't build something real is a week your confidence stays theoretical.**

You started this repo. Keep going. 💪

---

## 📚 Learning Order in This Repo

```
1. Kubernetes/   → Understand the platform you deploy to
2. Terraform/    → Learn to provision that platform as code
3. AWS/          → Understand the cloud the platform runs on
```

Each folder has a README with the exact learning path. Follow it in order.
