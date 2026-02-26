# 01 — What Is Terraform? 🌍

> **The core question**: Why write code to manage infrastructure when you can click in the AWS console?

---

## The Problem: Manual Infrastructure

Imagine you're setting up infrastructure for your OTEL pipeline. Without IaC, you:

1. Log into AWS Console
2. Click through 15 screens to create a VPC
3. Click through more screens to create subnets, route tables, EKS cluster...
4. Do it again for dev, staging, and prod environments
5. Three months later — nobody knows exactly what was configured or why

**What goes wrong:**

```
❌ "It works in dev but not in prod" — environments drift apart
❌ "Who deleted that security group?" — no audit trail
❌ "How do we rebuild this if the region goes down?" — no recovery plan
❌ "The new team member set something up slightly wrong" — human error
```

---

## The Solution: Infrastructure as Code (IaC)

IaC means you describe your infrastructure in **code files**, just like application code.

```
✅ Version controlled (Git) — full history of every change
✅ Reviewable — team reviews infrastructure changes like code PRs
✅ Repeatable — run the same code → get identical environments
✅ Automated — CI/CD pipelines apply changes, no manual clicking
✅ Documentable — the code IS the documentation
```

---

## What Is Terraform?

Terraform is an IaC tool made by **HashiCorp**. It lets you define infrastructure in `.tf` files, then:

```
┌─────────────────────────────────────────────────────────┐
│                   You write this:                        │
│                                                         │
│   resource "aws_s3_bucket" "my_bucket" {                │
│     bucket = "my-otel-data-bucket"                      │
│   }                                                     │
└────────────────────────┬────────────────────────────────┘
                         │   terraform apply
                         ▼
┌─────────────────────────────────────────────────────────┐
│               Terraform does this:                       │
│                                                         │
│   → Calls AWS API                                       │
│   → Creates the S3 bucket                              │
│   → Records what it created (state file)               │
│   → Next time: only changes what's different           │
└─────────────────────────────────────────────────────────┘
```

---

## How Terraform Works — The 3-Step Loop

```
┌──────────┐     terraform plan      ┌──────────────────────┐
│  .tf     │ ──────────────────────► │  Shows what WILL     │
│  files   │                         │  change (dry run)    │
└──────────┘                         └──────────┬───────────┘
                                                │
                                    terraform apply
                                                │
                                                ▼
                                    ┌──────────────────────┐
                                    │  Makes the changes   │
                                    │  in AWS              │
                                    └──────────┬───────────┘
                                               │
                                               ▼
                                    ┌──────────────────────┐
                                    │  Updates state file  │
                                    │  (terraform.tfstate) │
                                    └──────────────────────┘
```

**Always run `terraform plan` before `terraform apply`.** This is your safety net — you see exactly what will be created, changed, or destroyed before anything actually happens.

---

## Terraform vs Other IaC Tools

| Tool | Made By | Language | Use Case |
|------|---------|----------|----------|
| **Terraform** | HashiCorp | HCL | Multi-cloud, most widely used |
| **CloudFormation** | AWS | YAML/JSON | AWS-only, native integration |
| **Pulumi** | Pulumi | Python/TS/Go | Code-first, programmatic |
| **Ansible** | Red Hat | YAML | Config management (not infra) |
| **CDK** | AWS | Python/TS | AWS-only, developer-friendly |

**Why Terraform in your context:**
- Your stack spans many AWS services — Terraform handles all of them
- Your team likely uses Terraform already (industry standard)
- Module ecosystem is huge — most AWS services have community modules
- Works with EKS, SQS, API Gateway, VPC — everything in your OTEL stack

---

## Your First Terraform File

Create a file called `main.tf`:

```hcl
# This tells Terraform which cloud provider to use
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # Use version 5.x
    }
  }
}

# Configure the AWS provider (region, credentials)
provider "aws" {
  region = "us-east-1"
}

# Create an S3 bucket (like the one in your OTEL pipeline)
resource "aws_s3_bucket" "otel_data" {
  bucket = "my-otel-data-bucket-12345"  # Must be globally unique

  tags = {
    Name        = "OTEL Data Bucket"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

Run it:

```bash
terraform init      # Download the AWS provider plugin
terraform plan      # See what will be created
terraform apply     # Create it (type 'yes' to confirm)
terraform destroy   # Delete everything (clean up when learning)
```

---

## Key Mental Model

> 🔑 **Think of Terraform like Git for infrastructure.**
> - `.tf` files = source code
> - `terraform.tfstate` = the "deployed" snapshot
> - `terraform plan` = `git diff` (shows differences)
> - `terraform apply` = `git push` to prod (makes it real)
> - `terraform destroy` = delete everything (use with extreme caution in prod)

---

## ⚠️ What Terraform Is NOT

- **Not a configuration tool** — it creates infrastructure, not app configs (use Ansible/Helm for that)
- **Not idempotent by magic** — you must write your code to be idempotent
- **Not a replacement for understanding AWS** — you must know what you're creating

---

## ✅ Test Your Understanding

Before moving to Module 02, answer these:

1. If you run `terraform apply` twice with no changes to your `.tf` files, what happens?
2. What's the difference between `terraform plan` and `terraform apply`?
3. In your OTEL pipeline, name 3 AWS resources you could manage with Terraform.

> **Answers**: 1) Nothing changes — Terraform compares state to `.tf` and finds no differences. 2) Plan is a dry run (read-only), apply makes real changes. 3) Any of: VPC, SQS, DLQ, API Gateway, EKS, S3, NLB, Route53 records.

---

**Next**: [02 — Core Concepts](./02-core-concepts.md) → Providers, resources, state, and the plan/apply cycle in depth.
