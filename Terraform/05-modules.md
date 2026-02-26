# 05 — Modules 📦

> **The most important Terraform skill**: Write infrastructure once. Reuse it everywhere.

---

## What Is a Module?

A module is just a **folder of `.tf` files** that can be called from other Terraform code. You've been using one this whole time — your root project is a module (the "root module").

```
Without modules:            With modules:
─────────────────           ────────────────────────
main.tf (1000 lines)        main.tf (50 lines)
  - VPC code                  calls module "vpc"
  - subnet code               calls module "rds"
  - RDS code                  calls module "security-group"
  - security group code
  - EC2 code               modules/
  - ALB code                  vpc/
                              rds/
                              security-group/
```

---

## Module Structure

Every module has the same three files at minimum:

```
modules/vpc/
├── main.tf        ← What the module creates
├── variables.tf   ← What inputs the module accepts
└── outputs.tf     ← What values the module exposes
```

---

## Writing Your First Module

### The Module Files

```hcl
# modules/vpc/variables.tf
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets into"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}
```

```hcl
# modules/vpc/main.tf
locals {
  name_prefix = "${var.environment}-vpc"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = local.name_prefix, Environment = var.environment }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${local.name_prefix}-public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = { Name = "${local.name_prefix}-private-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}
```

---

## Calling a Module (The Root Module)

```hcl
# root/main.tf

# Call the vpc module for dev
module "vpc" {
  source = "./modules/vpc"   # Path to the module folder

  # Pass values to the module's variables
  vpc_cidr             = "10.0.0.0/16"
  environment          = "dev"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

# Use the module's outputs in other resources
resource "aws_eks_cluster" "main" {
  name = "platform-cluster"

  vpc_config {
    subnet_ids = module.vpc.private_subnet_ids   # ← Module output
  }
}

# Output the module's values to the root
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

---

## Module Sources — Where Modules Come From

```hcl
# 1. Local path (modules you write yourself)
module "vpc" {
  source = "./modules/vpc"
}

# 2. Git repository
module "vpc" {
  source = "git::https://github.com/mycompany/terraform-modules.git//vpc?ref=v1.2.0"
}

# 3. Terraform Registry (community modules)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}

# 4. S3 bucket
module "vpc" {
  source = "s3::https://s3.amazonaws.com/mybucket/modules/vpc.zip"
}
```

> 🔑 **Best practice**: Use versioned sources (`ref=v1.2.0` or `version = "~> 5.0"`). Never use unversioned module references in production — a module update could break your infrastructure silently.

---

## Using Community Modules (Terraform Registry)

Don't reinvent the wheel. The community has battle-tested modules for everything:

```hcl
# terraform-aws-modules/vpc is the most popular VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "platform-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = { ManagedBy = "terraform" }
}
```

Popular community modules:
- `terraform-aws-modules/vpc/aws` — VPC, subnets, routing
- `terraform-aws-modules/eks/aws` — EKS cluster and node groups
- `terraform-aws-modules/rds/aws` — RDS instances
- `terraform-aws-modules/alb/aws` — Application Load Balancer
- `terraform-aws-modules/s3-bucket/aws` — S3 with all options

---

## Module Versioning — Locking for Safety

When writing your own modules for a team:

```
modules/
  vpc/
    CHANGELOG.md    ← Track what changed and when
    README.md       ← Document inputs, outputs, examples

# Call with a version tag from Git:
module "vpc" {
  source = "git::ssh://git@github.com/mycompany/tf-modules.git//vpc?ref=v2.1.0"
}
```

Semantic versioning convention:
```
v1.0.0 → Initial release
v1.0.1 → Bug fix (backward compatible)
v1.1.0 → New optional feature (backward compatible)
v2.0.0 → Breaking change (rename variable, change output structure)
```

---

## Project Structure with Modules

```
terraform-platform/
├── environments/
│   ├── dev/
│   │   ├── main.tf        ← Calls modules with dev values
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf        ← Same modules, prod values
│       ├── backend.tf
│       └── terraform.tfvars
└── modules/
    ├── vpc/
    ├── eks/
    ├── rds/
    ├── alb/
    └── security-group/
```

---

## ✅ Test Your Understanding

1. What are the three standard files every module should have?
2. What is the difference between `source = "./modules/vpc"` and `source = "terraform-aws-modules/vpc/aws"`?
3. You updated a module's `variables.tf` to rename an existing variable. What happens to the engineers calling this module if they don't update their code?

> **Answers**: 1) `main.tf`, `variables.tf`, `outputs.tf`. 2) Local path loads from your filesystem. Registry loads from the Terraform public registry (requires `terraform init` to download). 3) `terraform plan` fails with "An argument named X is not expected here" — this is a breaking change. You should version your module (v2.x) so existing callers don't break automatically.

---

**Next**: [06 — Workspaces & Environments](./06-workspaces-environments.md) → Managing multiple environments cleanly.
