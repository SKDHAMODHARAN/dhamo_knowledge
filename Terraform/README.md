# Terraform — Complete Learning Path 🚀

> **From "What's Infrastructure as Code?" to "I can provision production AWS infrastructure confidently"**
>
> Written for someone with zero Terraform experience.
> Every concept uses real-world analogies, ASCII diagrams, and hands-on `.tf` examples.
> All examples use the same AWS stack you work with daily: **VPC, EKS, SQS, S3, API Gateway**.

---

## 🗺️ Learning Roadmap

```text
YOU ARE HERE
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 1 — FOUNDATIONS (Start here, no shortcuts!)              │
│                                                                 │
│  01. What Is Terraform?       ← Why IaC exists, how it works   │
│  02. Core Concepts            ← Provider, resource, state, plan │
│  03. Variables & Outputs      ← Making Terraform reusable       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 2 — REAL-WORLD PATTERNS (You'll use these every day)    │
│                                                                 │
│  04. State Management         ← Remote state, S3 backend, locks │
│  05. Modules                  ← Write once, use everywhere      │
│  06. Workspaces & Envs        ← Dev / staging / prod separation │
│  07. Providers & Data Sources ← AWS provider deep dive          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 3 — PRODUCTION READINESS (What separates dev from prod) │
│                                                                 │
│  08. Loops & Conditionals     ← count, for_each, dynamic blocks │
│  09. Security Best Practices  ← Secrets, IAM, least privilege   │
│  10. CI/CD with Terraform     ← GitHub Actions + Terraform      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  LEVEL 4 — MASTERY (Staff-level thinking)                      │
│                                                                 │
│  11. Production Best Practices ← Tagging, drift, cost, locking  │
│  12. Troubleshooting           ← Debug like a pro, state surgery│
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Folder Structure

```text
Terraform/
├── README.md                          ← You are here
├── 01-what-is-terraform.md            ← Start here
├── 02-core-concepts.md
├── 03-variables-outputs.md
├── 04-state-management.md
├── 05-modules.md
├── 06-workspaces-environments.md
├── 07-providers-and-data-sources.md
├── 08-loops-and-conditionals.md
├── 09-security-best-practices.md
├── 10-ci-cd-with-terraform.md
├── 11-production-best-practices.md
├── 12-troubleshooting.md
└── modules/                           ← Hands-on reusable Terraform modules
    ├── vpc/                           ← VPC + subnets + routing
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── s3-bucket/                     ← S3 with versioning + encryption
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── sqs-queue/                     ← SQS + DLQ pair
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── eks-cluster/                   ← EKS cluster + node group
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── root-example/                  ← Wires all modules together (real-world pattern)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── backend.tf
```

---

## 🎯 How to Use This Guide

1. **Go in order** — each module builds on the previous one
2. **Read the diagrams** — they show you what the text explains
3. **Study the modules/** — every `.tf` file is heavily commented for learning
4. **Challenge yourself** — each module has a "Test Your Understanding" section
5. **Bookmark troubleshooting** — you'll need it when `terraform apply` goes wrong

---

## 🛠️ Prerequisites

| Tool | What It Is | Install |
|------|-----------|---------|
| **Terraform** | The IaC tool itself | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| **AWS CLI** | Authenticate with AWS | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| **tfenv** | Manage multiple Terraform versions | [github.com/tfutils/tfenv](https://github.com/tfutils/tfenv) |

### Quick Setup

```bash
# Install tfenv (Terraform version manager — always use this in teams)
brew install tfenv        # macOS
# or
git clone https://github.com/tfutils/tfenv.git ~/.tfenv   # Linux

# Install and use a specific Terraform version
tfenv install 1.7.0
tfenv use 1.7.0

# Verify
terraform version

# Configure AWS credentials
aws configure
# Enter: Access Key, Secret Key, Region (e.g. us-east-1), Output format (json)

# Verify AWS access
aws sts get-caller-identity
```

---

## 🧭 Quick Reference — "Where Do I Find...?"

| I want to... | Go to |
|---|---|
| Understand why Terraform exists | `01-what-is-terraform.md` |
| Learn provider/resource/state basics | `02-core-concepts.md` |
| Make my code reusable with variables | `03-variables-outputs.md` |
| Store state safely in S3 | `04-state-management.md` |
| Write reusable modules | `05-modules.md` |
| Separate dev/staging/prod | `06-workspaces-environments.md` |
| Look up existing AWS resources | `07-providers-and-data-sources.md` |
| Create multiple resources in a loop | `08-loops-and-conditionals.md` |
| Handle secrets safely | `09-security-best-practices.md` |
| Run Terraform in GitHub Actions | `10-ci-cd-with-terraform.md` |
| Prepare for production | `11-production-best-practices.md` |
| Debug a broken `terraform apply` | `12-troubleshooting.md` |
| Get copy-paste `.tf` files | `modules/` folder |
