# 03 — Variables & Outputs 🔧

> **The goal**: Write Terraform once, deploy to dev, staging, and prod — without copy-pasting a single line.

---

## Why Variables?

Without variables — this is what most beginners write:

```hcl
# ❌ BAD — you'd need 3 copies of this for dev/staging/prod
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"   # hardcoded
}

resource "aws_s3_bucket" "logs" {
  bucket = "company-logs-dev"   # hardcoded env name
}
```

With variables — write once, configure per environment:

```hcl
# ✅ GOOD — one codebase, any environment
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_s3_bucket" "logs" {
  bucket = "company-logs-${var.environment}"
}
```

---

## Input Variables

### All Variable Types You'll Use

```hcl
# variables.tf

# --- Strings ---
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

# --- Numbers ---
variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 1
}

# --- Booleans ---
variable "enable_deletion_protection" {
  description = "Prevent accidental deletion of resources"
  type        = bool
  default     = false   # true in prod, false in dev
}

# --- Lists ---
variable "availability_zones" {
  description = "AZs to spread resources across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to reach the bastion host"
  type        = list(string)
  default     = []
}

# --- Maps ---
variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Team      = "platform"
  }
}

# --- Objects (structured config) ---
variable "rds_config" {
  description = "RDS instance configuration"
  type = object({
    instance_class    = string
    allocated_storage = number
    multi_az          = bool
  })
  default = {
    instance_class    = "db.t3.micro"
    allocated_storage = 20
    multi_az          = false
  }
}
```

### Using Variables in Resources

```hcl
# main.tf

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = merge(var.common_tags, {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  })
}

resource "aws_db_instance" "main" {
  instance_class    = var.rds_config.instance_class    # Access object fields
  allocated_storage = var.rds_config.allocated_storage
  multi_az          = var.rds_config.multi_az
  deletion_protection = var.enable_deletion_protection
}
```

---

## How to Pass Variable Values

### Method 1: Default values (fallback for optional vars)

```hcl
variable "environment" {
  type    = string
  default = "dev"   # Used if nothing else is provided
}
```

### Method 2: `.tfvars` files — one per environment ✅ Recommended

```hcl
# environments/dev.tfvars
environment                = "dev"
vpc_cidr                   = "10.0.0.0/16"
instance_count             = 1
enable_deletion_protection = false
availability_zones         = ["us-east-1a", "us-east-1b"]
rds_config = {
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  multi_az          = false
}
```

```hcl
# environments/prod.tfvars
environment                = "prod"
vpc_cidr                   = "10.1.0.0/16"
instance_count             = 3
enable_deletion_protection = true
availability_zones         = ["us-east-1a", "us-east-1b", "us-east-1c"]
rds_config = {
  instance_class    = "db.r6g.large"
  allocated_storage = 100
  multi_az          = true
}
```

```bash
# Apply for dev
terraform apply -var-file="environments/dev.tfvars"

# Apply for prod
terraform apply -var-file="environments/prod.tfvars"
```

### Method 3: Environment variables (great for CI/CD secrets)

```bash
# Terraform reads TF_VAR_<name> automatically
export TF_VAR_environment="prod"
export TF_VAR_db_password="SuperSecret!"
terraform apply
```

### Variable Precedence (highest to lowest)

```
1. -var flag on command line                 (highest priority)
2. -var-file flag on command line
3. terraform.tfvars (auto-loaded if present)
4. TF_VAR_xxx environment variables
5. Default values in variable block           (lowest priority)
```

---

## Variable Validation — Catch Mistakes Early

```hcl
variable "environment" {
  type = string

  # Reject anything other than these three values
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "instance_count" {
  type = number

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count must be between 1 and 10."
  }
}
```

---

## Locals — Computed Values

**Locals** are like variables, but computed from other values. They reduce repetition.

```hcl
# locals.tf

locals {
  # Build a consistent name prefix
  name_prefix = "${var.project_name}-${var.environment}"

  # Merge common tags with environment-specific ones
  # Every resource uses this — define once, reuse everywhere
  common_tags = merge(var.common_tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  })

  # Computed value — avoids recalculating in multiple places
  is_prod = var.environment == "prod"

  # AZ count for multi-AZ decision logic
  az_count = length(var.availability_zones)
}
```

Using locals:

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_db_instance" "main" {
  multi_az            = local.is_prod      # prod gets multi-AZ, dev doesn't
  deletion_protection = local.is_prod      # prod has protection, dev doesn't
  tags                = local.common_tags
}
```

### Variable vs Local — When to Use Each

| | `variable` | `local` |
|--|---|---|
| **Set by** | User / CI system | Computed inside code |
| **Can be overridden** | Yes, at runtime | No |
| **Use for** | Environment-specific config | Computed values, DRY expressions |

---

## Outputs

**Outputs** expose values after `terraform apply` for humans or other Terraform configs to consume.

```hcl
# outputs.tf

output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of all public subnets"
  value       = aws_subnet.public[*].id   # All subnet IDs as a list
}

output "private_subnet_ids" {
  description = "IDs of all private subnets"
  value       = aws_subnet.private[*].id
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = aws_db_instance.main.endpoint
}

# Sensitive output — value is hidden from terminal logs
output "rds_password" {
  description = "RDS master password"
  value       = aws_db_instance.main.password
  sensitive   = true
}
```

After `terraform apply`:

```bash
terraform output                    # Show all outputs
terraform output vpc_id             # Show one specific output
terraform output -json              # JSON format (for scripts/pipelines)
terraform output -raw vpc_id        # Raw value (no quotes, good for shell scripts)
```

---

## Recommended File Structure

```
project/
├── providers.tf     ← terraform{} block and provider config
├── main.tf          ← All resource definitions
├── variables.tf     ← All variable declarations
├── outputs.tf       ← All output declarations
├── locals.tf        ← All local values
├── environments/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
└── README.md        ← Document what this deploys and how to run it
```

---

## Handling Secrets — What NOT to Do

```hcl
# ❌ NEVER — secrets committed to Git
variable "db_password" {
  default = "SuperSecret123!"   # Now in Git history FOREVER
}

# ❌ NEVER — secrets in .tfvars files that are committed
# prod.tfvars:
# db_password = "SuperSecret123!"

# ✅ DO — use environment variables for secrets
# export TF_VAR_db_password="SuperSecret123!"

# ✅ DO — use AWS Secrets Manager or SSM and reference it
data "aws_ssm_parameter" "db_password" {
  name            = "/platform/prod/db-password"
  with_decryption = true
}

resource "aws_db_instance" "main" {
  password = data.aws_ssm_parameter.db_password.value
}
```

---

## ✅ Test Your Understanding

1. What is the difference between a `variable` and a `local`?
2. You run `terraform apply -var="environment=prod"` but also have `default = "dev"` in the variable block. Which value is used?
3. Why should you mark an output as `sensitive = true`? Does it encrypt the value in the state file?

> **Answers**: 1) Variables are external inputs set by users or CI systems. Locals are computed values inside your code. 2) `prod` — the -var flag always wins over defaults. 3) It hides the value from terminal output and logs — but it does NOT encrypt it in the state file. The value is still plaintext in tfstate (which is why you must encrypt and secure your state bucket!).

---

**Next**: [04 — State Management](./04-state-management.md) → The most important concept for team environments.
