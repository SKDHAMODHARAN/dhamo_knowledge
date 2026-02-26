# 06 — Workspaces & Environments 🌍

> **The real question**: How do you manage dev, staging, and prod with the same Terraform code — without breaking prod when you test in dev?

---

## The Two Approaches

There are two main patterns for multi-environment Terraform. Know both — each has real-world trade-offs.

```
┌─────────────────────────────┬──────────────────────────────────────┐
│  Approach 1: Workspaces     │  Approach 2: Directory-per-env       │
├─────────────────────────────┼──────────────────────────────────────┤
│  One codebase               │  One codebase                        │
│  Multiple state files       │  Separate state per folder           │
│  Switched via CLI           │  Separate terraform apply per folder │
├─────────────────────────────┼──────────────────────────────────────┤
│  Good for:                  │  Good for:                           │
│  - Small/simple setups      │  - Production systems ✅              │
│  - Quick testing            │  - Clear isolation                   │
│  - Learning                 │  - Different configs per env         │
├─────────────────────────────┼──────────────────────────────────────┤
│  Risk:                      │  Risk:                               │
│  - Easy to apply to wrong   │  - More files to maintain            │
│    workspace (human error!) │  - Some duplication                  │
└─────────────────────────────┴──────────────────────────────────────┘
```

---

## Approach 1: Terraform Workspaces

Each workspace has its own state file — same code, different state.

```bash
# List workspaces
terraform workspace list

# Create a new workspace
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch to a workspace
terraform workspace select prod

# Show current workspace
terraform workspace show

# Delete a workspace (must switch away first)
terraform workspace delete dev
```

Workspace state files in S3:

```
mycompany-terraform-state/
├── env:/
│   ├── dev/platform/terraform.tfstate
│   ├── staging/platform/terraform.tfstate
│   └── prod/platform/terraform.tfstate
└── platform/terraform.tfstate    ← "default" workspace
```

### Using Workspace Name in Code

```hcl
locals {
  environment = terraform.workspace   # "dev", "staging", or "prod"

  is_prod = terraform.workspace == "prod"

  # Different sizes per environment
  instance_type = {
    dev     = "t3.micro"
    staging = "t3.medium"
    prod    = "r6g.large"
  }

  rds_instance_class = {
    dev     = "db.t3.micro"
    staging = "db.t3.medium"
    prod    = "db.r6g.xlarge"
  }
}

resource "aws_instance" "web" {
  instance_type = local.instance_type[terraform.workspace]
  count         = local.is_prod ? 3 : 1   # 3 instances in prod, 1 in dev
}

resource "aws_db_instance" "main" {
  instance_class      = local.rds_instance_class[terraform.workspace]
  multi_az            = local.is_prod
  deletion_protection = local.is_prod
}
```

### Workflow with Workspaces

```bash
# Dev workflow
terraform workspace select dev
terraform apply -var-file="dev.tfvars"

# Promote to staging
terraform workspace select staging
terraform apply -var-file="staging.tfvars"

# Prod deploy (require explicit confirmation)
terraform workspace select prod
terraform plan -var-file="prod.tfvars" -out=prod.tfplan
terraform apply prod.tfplan
```

⚠️ **Workspace Gotcha**: It's easy to forget which workspace you're in. Always check before applying:
```bash
terraform workspace show   # Always run this first!
```

---

## Approach 2: Directory-per-Environment ✅ Recommended for Production

```
terraform-platform/
├── modules/                 ← Shared code (no state)
│   ├── vpc/
│   ├── eks/
│   ├── rds/
│   └── alb/
│
└── environments/
    ├── dev/
    │   ├── main.tf          ← Calls modules with dev config
    │   ├── backend.tf       ← State in S3 under dev/ path
    │   ├── variables.tf
    │   └── terraform.tfvars
    │
    ├── staging/
    │   ├── main.tf          ← Same modules, staging config
    │   ├── backend.tf       ← State in S3 under staging/ path
    │   ├── variables.tf
    │   └── terraform.tfvars
    │
    └── prod/
        ├── main.tf          ← Same modules, prod config
        ├── backend.tf       ← State in S3 under prod/ path
        ├── variables.tf
        └── terraform.tfvars
```

Each environment has its own backend:

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket = "mycompany-terraform-state"
    key    = "environments/dev/terraform.tfstate"   # dev-specific path
    region = "us-east-1"
    dynamodb_table = "mycompany-terraform-locks"
    encrypt = true
  }
}
```

```hcl
# environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket = "mycompany-terraform-state"
    key    = "environments/prod/terraform.tfstate"  # prod-specific path
    region = "us-east-1"
    dynamodb_table = "mycompany-terraform-locks"
    encrypt = true
  }
}
```

Each environment calls the same modules with different values:

```hcl
# environments/dev/main.tf
module "vpc" {
  source  = "../../modules/vpc"
  environment          = "dev"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}
```

```hcl
# environments/prod/main.tf
module "vpc" {
  source  = "../../modules/vpc"
  environment          = "prod"
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
}
```

### Workflow with Directory-per-Env

```bash
# Deploy dev
cd environments/dev
terraform init
terraform plan
terraform apply

# Deploy prod
cd environments/prod
terraform init
terraform plan   # Always review before prod
terraform apply
```

**Why this is better for prod**: You can't accidentally apply dev config to prod. The directories are physically separate. State isolation is structural, not just a CLI flag.

---

## Comparing Real-World Usage

| Scenario | Workspaces | Directory-per-env |
|---|---|---|
| Learning/experiments | ✅ Great | Overkill |
| Small team, simple app | ✅ OK | Also fine |
| Multiple teams | ❌ Risky | ✅ Better |
| Different resource counts per env | ✅ Works | ✅ Works |
| Different modules per env | ❌ Hard | ✅ Easy |
| CI/CD pipelines | ❌ Complex | ✅ Simple |
| Audit & compliance | ❌ Less clear | ✅ Explicit |

---

## Environment Promotion Strategy

```
Code change → PR → Plan on dev → Apply dev
                              → Plan on staging → Apply staging → Manual approval
                                                              → Plan on prod → Apply prod
```

In CI/CD (GitHub Actions):
```yaml
# Run plan automatically on every PR
on: pull_request
  → terraform plan (dev)

# Apply after merge to main
on: push to main
  → terraform apply (dev)

# Staging/prod require manual approval gate
  → Requires GitHub Environment Protection Rules
```

---

## ✅ Test Your Understanding

1. What is the main risk of using Terraform workspaces compared to directory-per-env?
2. You have a prod environment with 3 EKS nodes and a dev environment with 1. How would you implement this with directory-per-env?
3. A teammate ran `terraform apply` in the wrong workspace and deleted prod resources. What process would prevent this?

> **Answers**: 1) Human error — you can forget which workspace you're in and apply to the wrong environment. Directory-per-env makes this impossible structurally. 2) Set `node_count = 3` in `prod/terraform.tfvars` and `node_count = 1` in `dev/terraform.tfvars`. Same module code, different values. 3) Use directory-per-env + CI/CD pipelines that apply to prod only after manual approval. Add `prevent_destroy` to critical resources. Restrict IAM permissions so the dev role can't touch prod.

---

**Next**: [07 — Providers & Data Sources](./07-providers-and-data-sources.md) → AWS provider deep dive and looking up existing infrastructure.
