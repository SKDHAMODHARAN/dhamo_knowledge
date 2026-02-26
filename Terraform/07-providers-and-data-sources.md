# 07 — Providers & Data Sources 🔌

> **The gateway to everything**: Providers are how Terraform talks to every platform. Data sources are how you read existing infrastructure you didn't create.

---

## Provider Deep Dive

### The AWS Provider — Full Configuration

```hcl
# providers.tf

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"      # Accept 5.x, reject 6.x
    }
    # You can use multiple providers
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Assume a role (recommended for CI/CD and cross-account access)
  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/TerraformDeployRole"
    session_name = "terraform-session"
  }

  # Default tags applied to EVERY resource this provider creates
  # This is the cleanest way to enforce tagging at scale
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = var.environment
      Team        = "platform"
      Repository  = "github.com/mycompany/terraform-platform"
    }
  }
}
```

### Multiple Provider Configurations (Aliases)

Use when you need to deploy to multiple AWS regions or accounts:

```hcl
# Primary region
provider "aws" {
  region = "us-east-1"
}

# Alias for a second region (DR, global resources)
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}

# ACM cert must be in us-east-1 for CloudFront
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Use the aliased provider in a resource
resource "aws_acm_certificate" "cert" {
  provider    = aws.us_east_1   # Explicitly target us-east-1
  domain_name = "example.com"
  validation_method = "DNS"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west   # Explicitly target eu-west-1
  bucket   = "mycompany-backup-replica"
}
```

### Cross-Account Access

Platform engineers often manage infrastructure across multiple AWS accounts:

```hcl
# providers.tf

# Your "management" account (where Terraform runs)
provider "aws" {
  region = "us-east-1"
}

# Target: dev account
provider "aws" {
  alias  = "dev"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/TerraformRole"
  }
}

# Target: prod account
provider "aws" {
  alias  = "prod"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::999999999999:role/TerraformRole"
  }
}

# Create the same VPC in both accounts
module "vpc_dev" {
  source    = "./modules/vpc"
  providers = { aws = aws.dev }
  vpc_cidr  = "10.0.0.0/16"
}

module "vpc_prod" {
  source    = "./modules/vpc"
  providers = { aws = aws.prod }
  vpc_cidr  = "10.1.0.0/16"
}
```

---

## Provider Lock File

The `.terraform.lock.hcl` file pins exact provider versions:

```hcl
# .terraform.lock.hcl (auto-generated — COMMIT THIS FILE)
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.37.0"
  constraints = "~> 5.0"
  hashes = [
    "h1:xyz...",  # Checksum for integrity verification
  ]
}
```

```bash
# Update providers to latest allowed version
terraform providers lock -platform=linux_amd64 -platform=darwin_amd64

# Upgrade to newer provider version
terraform init -upgrade
```

> ✅ Commit `.terraform.lock.hcl` to Git — it ensures everyone on the team uses the exact same provider version.

---

## Data Sources Deep Dive

Data sources let you **read** existing infrastructure without managing it. They start with `data.` instead of `resource.`.

### Common AWS Data Sources

```hcl
# Current AWS account info (very commonly used)
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Use them to build ARNs dynamically
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  bucket_arn = "arn:aws:s3:::mybucket"
  lambda_arn = "arn:aws:lambda:${local.region}:${local.account_id}:function:my-fn"
}
```

```hcl
# Get the latest Amazon Linux 2023 AMI — always current, never hardcode AMI IDs
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2023.id   # Always latest
  instance_type = "t3.micro"
}
```

```hcl
# Look up an existing VPC by tag
data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = ["platform-vpc"]
  }
}

# Look up all existing subnets inside that VPC
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# Look up a specific EC2 instance
data "aws_instance" "bastion" {
  filter {
    name   = "tag:Name"
    values = ["platform-bastion"]
  }
}
```

```hcl
# Look up an existing Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = "mycompany.com."
  private_zone = false
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.mycompany.com"
  type    = "A"
  # ...
}
```

```hcl
# Look up an existing ACM certificate
data "aws_acm_certificate" "main" {
  domain      = "*.mycompany.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Look up secrets from Secrets Manager
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = "prod/database/credentials"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
}

resource "aws_db_instance" "main" {
  username = local.db_creds["username"]
  password = local.db_creds["password"]
}
```

```hcl
# Look up an IAM role that already exists
data "aws_iam_role" "eks_node" {
  name = "eks-node-role"
}

# Look up SSM parameters
data "aws_ssm_parameter" "db_password" {
  name            = "/platform/prod/db-password"
  with_decryption = true
}
```

---

## The `aws_iam_policy_document` Data Source

This is one of the most-used data sources — it generates IAM policy JSON cleanly:

```hcl
# Generate an S3 bucket policy
data "aws_iam_policy_document" "s3_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.data.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = data.aws_iam_policy_document.s3_policy.json   # Clean JSON output
}
```

---

## Data Sources vs Remote State

| Use case | Tool |
|---|---|
| Look up existing AWS resource (not managed by TF) | `data "aws_*"` |
| Look up output from another Terraform config | `data "terraform_remote_state"` |
| Manage a resource | `resource` |

---

## ✅ Test Your Understanding

1. Why is it better to use `data "aws_ami"` than hardcoding an AMI ID in your resource?
2. Your team has a shared VPC created by the networking team's Terraform. Your application module needs the VPC ID. You have two options: `data "aws_vpc"` or `data "terraform_remote_state"`. When would you choose each?
3. What does `provider "aws" { default_tags {} }` do, and why is it useful?

> **Answers**: 1) AMI IDs are region-specific and get deprecated/replaced — hardcoding causes breakage. Data sources always fetch the latest valid ID dynamically. 2) Use `aws_vpc` when you only need the VPC ID and don't need other outputs. Use `terraform_remote_state` when you need multiple outputs from the networking module (subnet IDs, route table IDs, etc). 3) Applies specified tags to EVERY resource the provider creates. This enforces consistent tagging across all resources without adding tags to each resource manually — critical for cost attribution and compliance.

---

**Next**: [08 — Loops & Conditionals](./08-loops-and-conditionals.md) → Create 10 subnets with 3 lines of code.
