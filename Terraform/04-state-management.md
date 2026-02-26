# 04 — State Management 🗄️

> **The #1 topic that breaks teams**: Without remote state, two engineers can corrupt your infrastructure with a single `terraform apply`.

---

## The Problem with Local State

Default behavior — Terraform saves state on your local machine:

```
my-project/
├── main.tf
├── variables.tf
└── terraform.tfstate   ← Saved locally. This is the problem.
```

### What Goes Wrong on a Team

```
Developer A runs terraform apply → state file on A's laptop
Developer B runs terraform apply → B's state is outdated
                                 → B thinks VPC doesn't exist
                                 → B RECREATES the VPC 💥
                                 → OR overwrites what A did 💥
```

Or worse:

```
Developer B deletes their laptop
  → State file is gone
  → Terraform no longer knows what exists in AWS
  → terraform plan tries to create EVERYTHING again
  → Including things that already exist = errors or duplicates
```

---

## The Solution: Remote State with S3 + DynamoDB

```
┌─────────────────────────────────────────────────────────┐
│  S3 Bucket              → Stores the state file         │
│  DynamoDB Table         → Provides locking               │
└─────────────────────────────────────────────────────────┘

Developer A:  terraform apply
  → Acquires DynamoDB lock
  → Reads current state from S3
  → Makes changes
  → Writes updated state to S3
  → Releases lock

Developer B:  terraform apply (at same time)
  → Tries to acquire lock
  → Lock exists! B waits (or fails fast with a clear error)
  → A finishes → lock released → B proceeds safely
```

---

## Step 1: Bootstrap — Create the State Bucket and Lock Table

Create this ONCE, before any other Terraform work. Store it in a separate `bootstrap/` folder:

```hcl
# bootstrap/main.tf

provider "aws" { region = "us-east-1" }

# ── S3 bucket to store all Terraform state ─────────────────────
resource "aws_s3_bucket" "terraform_state" {
  bucket = "mycompany-terraform-state"   # Must be globally unique

  lifecycle {
    prevent_destroy = true   # Never allow accidental deletion
  }

  tags = { Name = "Terraform State", ManagedBy = "terraform" }
}

# Enable versioning so you can recover from bad state
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

# Encrypt state at rest — state files contain sensitive data
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — state files must NEVER be public
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB table for distributed locking ──────────────────────
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "mycompany-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"   # Terraform requires this exact name

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "Terraform State Locks", ManagedBy = "terraform" }
}
```

Run this FIRST:
```bash
cd bootstrap/
terraform init
terraform apply   # Creates the S3 bucket and DynamoDB table
```

---

## Step 2: Configure Backend in Your Main Projects

Every other Terraform project now uses this backend:

```hcl
# backend.tf

terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "platform/vpc/terraform.tfstate"   # Path inside the bucket
    region         = "us-east-1"
    dynamodb_table = "mycompany-terraform-locks"
    encrypt        = true
  }
}
```

Reinitialize to migrate:
```bash
terraform init
# Asks: "Do you want to copy existing state to the new backend?" → yes
```

---

## State Path Strategy — Organize State by Project + Environment

```
S3: mycompany-terraform-state/
├── bootstrap/terraform.tfstate
│
├── platform/
│   ├── vpc/dev/terraform.tfstate
│   ├── vpc/staging/terraform.tfstate
│   ├── vpc/prod/terraform.tfstate
│   ├── eks/dev/terraform.tfstate
│   ├── eks/prod/terraform.tfstate
│   └── rds/prod/terraform.tfstate
│
├── security/
│   ├── iam/terraform.tfstate
│   └── guardduty/terraform.tfstate
│
└── applications/
    ├── api-service/dev/terraform.tfstate
    └── api-service/prod/terraform.tfstate
```

---

## Cross-Module State Reference

When one module needs values from another module's state:

```hcl
# In your EKS module — read VPC outputs from the networking module
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "mycompany-terraform-state"
    key    = "platform/vpc/prod/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_eks_cluster" "main" {
  name = "platform-cluster"

  vpc_config {
    subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  }
}
```

---

## Essential State Commands

```bash
# See everything Terraform is tracking
terraform state list

# Inspect a specific resource in state
terraform state show aws_vpc.main

# Remove from state WITHOUT deleting the resource in AWS
# Use case: you want to manage a resource differently, or move it to another config
terraform state rm aws_vpc.main

# Import an existing AWS resource into Terraform management
# Use case: someone created a VPC manually, now you want Terraform to own it
terraform import aws_vpc.main vpc-0abc1234

# Rename a resource in state (when you rename it in .tf code)
terraform state mv aws_vpc.old_name aws_vpc.new_name

# View full state as JSON
terraform show -json

# Force-unlock a stuck lock (if apply crashed mid-way)
terraform force-unlock <LOCK_ID>
```

---

## `prevent_destroy` Lifecycle Guard

Use on anything in production that should never be deleted:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_db_instance" "main" {
  # ...
  lifecycle {
    prevent_destroy       = true    # Don't delete the DB
    ignore_changes        = [password]  # Don't update if password changes outside TF
    create_before_destroy = true    # For zero-downtime replacements
  }
}
```

---

## Common State Mistakes

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Committing `terraform.tfstate` to Git | Plaintext secrets exposed | Remote state + `.gitignore` |
| Two engineers apply simultaneously | State corruption | Remote state + DynamoDB lock |
| Deleting state file | TF recreates everything | S3 versioning + backups |
| Editing `tfstate` by hand | State corruption | Use `terraform state` commands |
| Running `destroy` on prod | Infrastructure gone | `prevent_destroy` + IAM restrictions |

---

## `.gitignore` Additions for Terraform

```gitignore
# Local state (never commit)
*.tfstate
*.tfstate.*
*.tfstate.backup

# Downloaded provider plugins (re-downloaded via terraform init)
.terraform/

# Crash logs
crash.log
crash.*.log

# Commit this file — it locks provider versions for the team:
# .terraform.lock.hcl  ← DO commit this one

# Only ignore .tfvars if they contain secrets
*.tfvars
!example.tfvars   # Commit the example, not the real values
```

---

## ✅ Test Your Understanding

1. Why do we need both S3 AND DynamoDB — what does each one do?
2. A `terraform apply` fails halfway through. What is the state of the infrastructure and what do you do?
3. An engineer on your team created an EC2 instance manually in the AWS console. Your manager wants it managed by Terraform going forward. What command do you use?

> **Answers**: 1) S3 stores the actual state JSON file. DynamoDB provides distributed locking — prevents concurrent applies from corrupting state. 2) Partial state — some resources exist in AWS and are recorded in state; others failed. Run `terraform plan` to see what's missing, then `terraform apply` again to complete it. 3) `terraform import aws_instance.name <instance-id>` — then write the matching resource block in your .tf file.

---

**Next**: [05 — Modules](./05-modules.md) → The most important concept for writing maintainable, reusable infrastructure code.
