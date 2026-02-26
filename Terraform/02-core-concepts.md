# 02 — Core Concepts 🧱

> The four pillars of Terraform: **Provider → Resource → State → Plan/Apply**
>
> Master these and everything else makes sense.

---

## The Big Picture

```
┌───────────────────────────────────────────────────────────────┐
│                    Your .tf Files                             │
│                                                               │
│  provider "aws" { ... }         ← WHO you're talking to      │
│  resource "aws_vpc" "main" {    ← WHAT you want to create    │
│    ...                                                        │
│  }                                                            │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│                   Terraform Core                              │
│                                                               │
│  1. Reads .tf files                                           │
│  2. Reads state  (what currently exists in AWS)               │
│  3. Computes DIFF (what needs to change)                      │
│  4. Applies changes via provider APIs                         │
└────────────────────────┬──────────────────────────────────────┘
                         │
                         ▼
┌───────────────────────────────────────────────────────────────┐
│                 terraform.tfstate (State File)                │
│                                                               │
│  JSON file recording EVERYTHING Terraform has created         │
│  → Never edit this manually                                   │
│  → Store it remotely in S3 for teams (covered in Module 04)  │
└───────────────────────────────────────────────────────────────┘
```

---

## Concept 1: Providers

A **provider** is a plugin that knows how to talk to a specific platform (AWS, GCP, Azure, Kubernetes, GitHub, Datadog, etc.).

```hcl
# providers.tf

terraform {
  required_version = ">= 1.7.0"   # Lock minimum Terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"   # From registry.terraform.io
      version = "~> 5.0"          # Accept 5.x but not 6.x
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # HOW Terraform authenticates with AWS:
  #
  # Option 1: AWS CLI profile (best for local dev)
  #   Run: aws configure
  #
  # Option 2: Environment variables (great for CI/CD)
  #   export AWS_ACCESS_KEY_ID="..."
  #   export AWS_SECRET_ACCESS_KEY="..."
  #   export AWS_DEFAULT_REGION="us-east-1"
  #
  # Option 3: IAM Role (best for EC2/EKS/Lambda running Terraform)
  #   assume_role { role_arn = "arn:aws:iam::123456789:role/TerraformRole" }
}
```

When you run `terraform init`, it downloads the provider:

```bash
terraform init

# Output:
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0"...
# - Installing hashicorp/aws v5.37.0...
# Terraform has been successfully initialized!
```

---

## Concept 2: Resources

A **resource** is the thing you want to create in AWS. It maps 1:1 to an AWS service API call.

```hcl
# Syntax:
# resource "<PROVIDER>_<TYPE>" "<LOCAL_NAME>" {
#   argument = value
# }

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "main-vpc"
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id    # ← References the VPC above
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet-a"
  }
}
```

### Resource Naming Anatomy

```
resource "aws_vpc" "main"
         │         │
         │         └── LOCAL name — used ONLY inside this Terraform config
         └── RESOURCE TYPE — maps to AWS API (CreateVpc)

To reference this resource elsewhere use:
  aws_vpc.main.id
  aws_vpc.main.arn
  aws_vpc.main.cidr_block
```

> 🔑 The local name (`main`) has no effect on what gets created in AWS. It's just how you reference it in code. The `tags.Name` is what shows up in the AWS console.

---

## Concept 3: State

**State** is Terraform's memory. It records what infrastructure currently exists.

```
terraform.tfstate (simplified):
{
  "resources": [
    {
      "type": "aws_vpc",
      "name": "main",
      "instances": [{
        "attributes": {
          "id":         "vpc-0abc1234",
          "cidr_block": "10.0.0.0/16",
          "arn":        "arn:aws:ec2:us-east-1:123456789:vpc/vpc-0abc1234"
        }
      }]
    }
  ]
}
```

### How State Drives Decisions

```
┌──────────┐    ┌──────────────┐    ┌──────────────────────────────┐
│ .tf file │    │  State file  │    │           Result             │
├──────────┤    ├──────────────┤    ├──────────────────────────────┤
│  vpc     │ == │    vpc       │ →  │ No changes needed            │
│ exists   │    │  exists      │    │                              │
├──────────┤    ├──────────────┤    ├──────────────────────────────┤
│ vpc      │ != │    vpc       │ →  │ UPDATE vpc in AWS            │
│ dns=true │    │  dns=false   │    │                              │
├──────────┤    ├──────────────┤    ├──────────────────────────────┤
│ (empty)  │    │    vpc       │ →  │ DESTROY vpc in AWS           │
│          │    │  exists      │    │ (you removed it from .tf)    │
├──────────┤    ├──────────────┤    ├──────────────────────────────┤
│  vpc     │    │   (empty)    │ →  │ CREATE vpc in AWS            │
│ exists   │    │              │    │                              │
└──────────┘    └──────────────┘    └──────────────────────────────┘
```

> ⚠️ **Golden Rule**: Never delete or manually edit `terraform.tfstate`.

---

## Concept 4: The Plan → Apply → Destroy Cycle

### `terraform plan` — Your Safety Net

Always run this before apply. It's a read-only dry run.

```bash
terraform plan

# Output symbols:
# + will be CREATED
# ~ will be UPDATED in-place
# - will be DESTROYED
# -/+ DESTROY then RECREATE (most disruptive — read these carefully!)
```

Example plan output:

```
Terraform will perform the following actions:

  # aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + arn                  = (known after apply)
      + cidr_block           = "10.0.0.0/16"
      + enable_dns_hostnames = true
      + id                   = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

### `terraform apply`

```bash
terraform apply              # Shows plan again, prompts for "yes"
terraform apply -auto-approve  # Skips prompt — ONLY use in CI/CD pipelines
```

### `terraform destroy`

```bash
terraform destroy   # Destroys ALL resources managed by this config
# Use when: cleaning up dev/test environments
# NEVER run on prod without careful thought
```

---

## Concept 5: Resource References & Dependency Graph

Resources can reference each other. Terraform builds a dependency graph and creates them in the right order.

```hcl
# Terraform automatically knows VPC must exist before the subnet
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id   # → depends on VPC
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id   # → depends on VPC
  cidr_block = "10.0.1.0/24"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id   # → depends on IGW
  }
}
```

Dependency order resolved automatically:
```
aws_vpc.main
    ├──► aws_internet_gateway.main
    ├──► aws_subnet.public
    └──► aws_route_table.public (also needs igw)
```

Run `terraform graph | dot -Tpng > graph.png` to visualize it.

---

## Concept 6: Data Sources

**Data sources** let you look up existing resources that Terraform didn't create.

```hcl
# Look up the latest Amazon Linux 2023 AMI (changes frequently)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Look up your current AWS account ID
data "aws_caller_identity" "current" {}

# Look up an existing VPC created by another team
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["shared-platform-vpc"]
  }
}

# Use them all in a resource
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = data.aws_vpc.shared.id
}
```

> 🔑 **Rule**: Use `resource` for things Terraform manages. Use `data` to look up things that already exist outside your config.

---

## A Complete Working Example

```hcl
# providers.tf
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

# main.tf — Create a basic VPC with one public subnet
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "learning-vpc", ManagedBy = "terraform" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "learning-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-a" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# outputs.tf
output "vpc_id"       { value = aws_vpc.main.id }
output "subnet_id"    { value = aws_subnet.public.id }
```

Try it:
```bash
terraform init
terraform plan
terraform apply
# Done! You have a real VPC in AWS.
terraform destroy   # Clean up when done learning
```

---

## ✅ Test Your Understanding

1. If you run `terraform apply` twice with no changes to `.tf` files, what happens?
2. What's the difference between a `resource` and a `data` source?
3. You have `resource "aws_subnet" "public" { vpc_id = aws_vpc.main.id }`. If you run `terraform destroy`, which gets destroyed first — the VPC or the subnet?

> **Answers**: 1) Nothing — Terraform compares state to .tf files, finds no diff, makes 0 changes. 2) Resource = Terraform creates and manages it. Data = read-only lookup of something that already exists. 3) The subnet gets destroyed first (Terraform respects the dependency graph in reverse).

---

**Next**: [03 — Variables & Outputs](./03-variables-outputs.md) → Make your code reusable across environments.
