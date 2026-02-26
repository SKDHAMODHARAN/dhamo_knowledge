# 09 — Security Best Practices 🔐

> **The hard truth**: One misconfigured Terraform file can expose your entire infrastructure. Security in IaC is not optional.

---

## The Risk Landscape

```
Common security mistakes in Terraform:

1. Secrets committed to Git in .tf or .tfvars files
2. IAM roles with * permissions ("just to get it working")
3. Security groups open to 0.0.0.0/0 on all ports
4. S3 buckets with public access
5. Unencrypted state files with sensitive outputs
6. Hardcoded account IDs and resource ARNs
```

---

## Rule 1: Never Put Secrets in .tf Files

```hcl
# ❌ NEVER — these get committed to Git
variable "db_password" {
  default = "admin123"
}

resource "aws_db_instance" "main" {
  password = "admin123"   # Plaintext in code history FOREVER
}
```

### The Right Ways to Handle Secrets

**Option A: AWS Secrets Manager (best for production)**

```hcl
# Store your secret in AWS Secrets Manager manually or via sealed secrets
# Then reference it in Terraform:

data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/database/master-credentials"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
}

resource "aws_db_instance" "main" {
  username = local.db_creds["username"]
  password = local.db_creds["password"]
  # Never stored in .tf files, never in Git
}
```

**Option B: AWS SSM Parameter Store (simpler, cheaper)**

```hcl
data "aws_ssm_parameter" "db_password" {
  name            = "/platform/prod/db-password"
  with_decryption = true   # For SecureString parameters
}

resource "aws_db_instance" "main" {
  password = data.aws_ssm_parameter.db_password.value
}
```

**Option C: Environment variables (good for CI/CD)**

```bash
# In your CI/CD pipeline or shell — never in .tf files
export TF_VAR_db_password="$(aws secretsmanager get-secret-value --secret-id prod/db-password --query SecretString --output text | jq -r .password)"
terraform apply
```

**Option D: Sensitive variable (hides from logs, still in state)**

```hcl
variable "db_password" {
  type      = string
  sensitive = true   # Hides from terminal output
  # Still in tfstate — encrypt your S3 bucket!
}
```

---

## Rule 2: IAM Least Privilege

Give Terraform roles only the permissions they actually need:

```hcl
# ❌ NEVER in production
data "aws_iam_policy_document" "terraform_too_broad" {
  statement {
    effect    = "Allow"
    actions   = ["*"]         # Full access to everything
    resources = ["*"]
  }
}

# ✅ Scope down to exactly what's needed
data "aws_iam_policy_document" "terraform_vpc_only" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeVpcs",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      "ec2:CreateInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DeleteInternetGateway",
    ]
    resources = ["*"]
  }
}

# IAM role for Terraform CI/CD
resource "aws_iam_role" "terraform_deploy" {
  name = "terraform-deploy-role"

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = { ManagedBy = "terraform" }
}

# Scope by resource ARN where possible
data "aws_iam_policy_document" "s3_specific" {
  statement {
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    # Restrict to specific bucket, not all S3
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
}
```

### IAM Role for Terraform (Cross-Account Pattern)

```hcl
# In the TARGET account — role that Terraform assumes
resource "aws_iam_role" "terraform_role" {
  name = "TerraformDeployRole"

  # Only allow the management account to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.management_account_id}:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id   # Extra security
        }
      }
    }]
  })
}
```

---

## Rule 3: Security Groups — Deny by Default

```hcl
# ❌ BAD — opens everything to the internet
resource "aws_security_group" "web" {
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # The whole internet
  }
}

# ✅ GOOD — minimal, explicit rules
resource "aws_security_group" "web" {
  name   = "${var.environment}-web-sg"
  vpc_id = aws_vpc.main.id

  # Only accept HTTP/HTTPS from the internet
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Only allow app servers to be reached from the web tier (not internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # Outbound is typically unrestricted
  }

  tags = { Name = "${var.environment}-web-sg" }
}

resource "aws_security_group" "app" {
  name   = "${var.environment}-app-sg"
  vpc_id = aws_vpc.main.id

  # Only allow traffic FROM the web security group — not directly from internet
  ingress {
    description     = "From web tier only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]   # Reference by SG, not CIDR
  }
}
```

---

## Rule 4: Encrypt Everything

```hcl
# S3 — encrypt at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true   # Reduces KMS costs
  }
}

# S3 — block all public access (do this on EVERY bucket)
resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# RDS — encrypt storage
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Disable public access
  publicly_accessible = false
}

# EBS volumes — encrypted by default (account-level setting)
resource "aws_ebs_encryption_by_default" "main" {
  enabled = true
}
```

---

## Rule 5: Protect Production Resources

```hcl
resource "aws_db_instance" "prod" {
  # ...

  lifecycle {
    prevent_destroy = true          # Terraform refuses to delete this
    ignore_changes  = [password]    # Don't update if changed outside TF
  }

  deletion_protection = true        # AWS-level protection (requires this disabled to delete)
  skip_final_snapshot = false       # Take a snapshot before deletion
  final_snapshot_identifier = "prod-db-final-snapshot-${formatdate("YYYY-MM-DD", timestamp())}"
}
```

---

## Rule 6: Audit Trail — Tag Everything

```hcl
# Enforce tags via provider default_tags (Module 07)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = var.environment
      Repository  = var.github_repo
      Owner       = var.team_name
      CostCenter  = var.cost_center
    }
  }
}
```

---

## Rule 7: Scan Your Terraform Code

```bash
# tfsec — security scanner for Terraform
brew install tfsec
tfsec .

# Checkov — policy-as-code scanner
pip install checkov
checkov -d .

# terrascan
brew install terrascan
terrascan scan -t aws

# Example tfsec output:
# CRITICAL: Security group allows ingress from 0.0.0.0/0 on port 22 (SSH)
# MEDIUM: S3 bucket does not have versioning enabled
```

Add scanning to your CI pipeline:

```yaml
# .github/workflows/terraform-security.yml
- name: Security scan
  run: |
    tfsec . --no-color
    checkov -d . --framework terraform
```

---

## ✅ Test Your Understanding

1. You need to pass a database password to an RDS instance via Terraform. Walk through the safest approach step by step.
2. A security group has `cidr_blocks = ["0.0.0.0/0"]` on port 22 (SSH). Why is this a critical risk and how do you fix it?
3. Your Terraform state file (`terraform.tfstate`) contains a plaintext password for an RDS instance. Is this acceptable if the S3 bucket is encrypted?

> **Answers**: 1) Store the password in AWS Secrets Manager or SSM Parameter Store → use `data "aws_secretsmanager_secret_version"` to reference it → mark the variable as `sensitive = true` → never commit to Git. 2) This exposes SSH to the entire internet — bots will brute-force it within minutes. Fix: replace with the specific CIDR of your office/VPN, or use AWS Systems Manager Session Manager instead of SSH entirely. 3) Better than unencrypted, but not ideal. Use `sensitive = true` for outputs to keep them out of logs. Consider using AWS KMS customer-managed keys for the state bucket. The state file itself is a security boundary — restrict IAM access to it strictly.

---

**Next**: [10 — CI/CD with Terraform](./10-ci-cd-with-terraform.md) → Automate Terraform in GitHub Actions pipelines.
