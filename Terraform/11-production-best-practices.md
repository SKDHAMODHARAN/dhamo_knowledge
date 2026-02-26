# 11 — Production Best Practices 🏭

> **What separates "it works" from "it's production-ready"**: Tagging, locking, drift detection, cost awareness, and operational discipline.

---

## 1. Lock Terraform and Provider Versions

Always pin versions — infrastructure upgrades need to be intentional, not accidental:

```hcl
# terraform.tf

terraform {
  # Lock minimum Terraform version — prevents running old versions
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.37"   # Accept 5.37.x, not 5.38 (minor version lock)
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}
```

Commit `.terraform.lock.hcl` to Git:
```
# .terraform.lock.hcl ensures every team member and CI uses
# the EXACT same provider checksums
git add .terraform.lock.hcl
git commit -m "chore: lock provider versions"
```

---

## 2. Mandatory Tagging Strategy

Every resource in production must be tagged. Use `default_tags` in the provider:

```hcl
provider "aws" {
  region = var.aws_region

  # Applied to EVERY resource without exception
  default_tags {
    tags = {
      Environment  = var.environment            # dev/staging/prod
      ManagedBy    = "terraform"                # Identifies IaC-managed resources
      Repository   = "github.com/myco/tf-core" # Link back to the code
      Team         = var.owning_team            # Who owns this?
      CostCenter   = var.cost_center            # For billing reports
      CreatedBy    = "terraform"
    }
  }
}
```

**Why this matters:**
- AWS Cost Explorer can split bills by `CostCenter` tag
- Find all resources owned by a team with tag filters
- Identify orphaned resources (old envs, someone's test)
- Compliance audits require resource ownership metadata

---

## 3. Module Versioning

Never use unversioned module references in production:

```hcl
# ❌ BAD — module could change anytime, silently breaking your infra
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"   # No version = danger
}

# ✅ GOOD — pinned version, changes are intentional
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "= 5.5.0"   # Exact version (most strict)
}

# Also acceptable:
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"    # Accept 5.5.x patch versions only
}

# For internal modules with Git tags:
module "vpc" {
  source = "git::ssh://git@github.com/myco/modules.git//vpc?ref=v3.2.1"
}
```

---

## 4. Drift Detection

Drift = when AWS resources change outside of Terraform (manual console changes, scripts, etc.).

```bash
# Detect drift — compare actual AWS state to Terraform state
terraform plan -refresh-only

# Output shows what changed outside Terraform:
# ~ aws_security_group_rule.web will be updated in-place
#   ~ cidr_blocks = ["10.0.0.0/8"] -> ["0.0.0.0/0"]
#   (This means someone opened 0.0.0.0/0 manually in the console — fix it!)
```

**Run drift detection in CI on a schedule:**

```yaml
# .github/workflows/drift-detection.yml
on:
  schedule:
    - cron: '0 8 * * 1-5'   # Every weekday at 8am

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.TERRAFORM_ROLE_ARN }}
          aws-region: us-east-1
      - name: Check for Drift
        run: |
          terraform init
          terraform plan -refresh-only -detailed-exitcode
        # exit code 2 = changes detected (drift!)
        # exit code 0 = no drift
```

---

## 5. `moved` Block — Rename Resources Safely

When you rename a resource in Terraform, it would normally destroy the old one and create a new one. The `moved` block prevents this:

```hcl
# You renamed aws_instance.web_server to aws_instance.web
# Without this, Terraform would destroy web_server and create web
moved {
  from = aws_instance.web_server
  to   = aws_instance.web
}

# Also works for module renames
moved {
  from = module.old_vpc
  to   = module.vpc
}

# Works for for_each key changes
moved {
  from = aws_subnet.public["old-key"]
  to   = aws_subnet.public["new-key"]
}
```

---

## 6. Lifecycle Rules

```hcl
resource "aws_eks_node_group" "main" {
  # ...

  lifecycle {
    # ✅ For prod — never accidentally delete critical resources
    prevent_destroy = true

    # ✅ Create new resource BEFORE destroying old one (zero-downtime updates)
    create_before_destroy = true

    # ✅ Ignore fields managed outside Terraform (drift you accept)
    ignore_changes = [
      scaling_config[0].desired_size,   # Auto-scaler manages this
      tags["LastModified"],             # Updated by external processes
    ]
  }
}
```

---

## 7. Output Documentation

Document every output — future you (or a colleague) will thank you:

```hcl
output "vpc_id" {
  description = "ID of the main VPC. Used by EKS, RDS, and ALB modules to reference the network."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (one per AZ). Use for EKS nodes, RDS, Lambda in VPC."
  value       = aws_subnet.private[*].id
}

output "eks_cluster_endpoint" {
  description = "HTTPS endpoint for the EKS API server. Used by kubectl and Helm."
  value       = aws_eks_cluster.main.endpoint
}
```

---

## 8. Cost Controls

```hcl
# Always use instance types appropriate for the environment
locals {
  instance_types = {
    dev     = "t3.micro"
    staging = "t3.medium"
    prod    = "r6g.large"
  }
}

# Set budget alarms — alert before cost surprises
resource "aws_budgets_budget" "platform" {
  name         = "platform-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80           # Alert at 80% of budget
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.billing_alert_email]
  }
}

# For EKS — right-size nodes, don't over-provision in non-prod
# For RDS — use burstable instances (t3.micro) in dev
# For NAT Gateway — one NAT GW is enough for dev (not one per AZ)
resource "aws_nat_gateway" "main" {
  count         = var.environment == "prod" ? length(var.availability_zones) : 1

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}
```

---

## 9. Documentation in Code

```hcl
# Add comments explaining WHY, not what (the code shows what)

# Using NAT Gateway instead of NAT instance because:
# 1. Managed by AWS — no maintenance
# 2. Scales automatically up to 45 Gbps
# 3. High availability within AZ
resource "aws_nat_gateway" "main" {
  # ...
}

# db.t4g.micro is sufficient for dev traffic (<100 QPS)
# Change to db.r6g.large for prod (> 1000 QPS sustained)
resource "aws_db_instance" "main" {
  instance_class = local.db_instance_class[var.environment]
}
```

---

## Production Readiness Checklist

Before promoting to production, verify:

```
Infrastructure
[ ] All resources tagged with required tags
[ ] State stored in versioned, encrypted S3 with DynamoDB lock
[ ] Module versions pinned
[ ] `prevent_destroy = true` on critical resources
[ ] `deletion_protection` enabled on RDS/critical DBs
[ ] No security groups open to 0.0.0.0/0 on SSH/admin ports
[ ] All S3 buckets have public access blocked
[ ] All storage encrypted at rest

Operations
[ ] Drift detection running on schedule
[ ] Budget alerts configured
[ ] terraform apply only runs through CI/CD, not from laptops
[ ] OIDC auth configured (no long-lived credentials)
[ ] Runbook exists: what to do if terraform apply fails mid-way

Code Quality
[ ] terraform fmt passes
[ ] terraform validate passes
[ ] tfsec/checkov scan passes
[ ] All outputs have descriptions
[ ] Comments explain non-obvious decisions
[ ] .terraform.lock.hcl committed to Git
```

---

## ✅ Test Your Understanding

1. What is configuration drift and how does `terraform plan -refresh-only` help?
2. You need to rename `aws_s3_bucket.data` to `aws_s3_bucket.application_data` in your code. What happens without a `moved` block? What happens with one?
3. Your team has dev, staging, and prod. You have 3 NAT Gateways in dev. Fixing this saves $100/month. What does the Terraform change look like?

> **Answers**: 1) Drift = resources in AWS changed outside Terraform (console, CLI, scripts). `-refresh-only` re-reads real AWS state and shows a plan WITHOUT making changes — only updates state file. 2) Without moved: S3 bucket destroyed, new one created — **bucket contents deleted!** With `moved { from = aws_s3_bucket.data, to = aws_s3_bucket.application_data }`: only renamed in state, bucket in AWS untouched. 3) Change `count = length(var.availability_zones)` to `count = var.environment == "prod" ? length(var.availability_zones) : 1` for the NAT Gateways and EIPs.

---

**Next**: [12 — Troubleshooting](./12-troubleshooting.md) → Debug like a pro when terraform apply goes wrong.
