# modules/iam-role/main.tf
#
# PURPOSE: Creates a reusable IAM role with flexible trust policies.
# Supports EC2/EKS service roles, cross-account roles, and GitHub Actions OIDC.
#
# WHAT EVERY PLATFORM ENGINEER NEEDS TO KNOW:
# - Trust policy = WHO can assume this role
# - Permission policy = WHAT this role can do once assumed
# - Always apply least privilege — never use Action: "*" or Resource: "*"
# - OIDC for GitHub Actions = no long-lived credentials in your CI/CD

data "aws_caller_identity" "current" {}

# Build the trust policy document dynamically
data "aws_iam_policy_document" "assume_role" {
  # Trust AWS services (e.g., EC2, EKS, Lambda can assume this role)
  dynamic "statement" {
    for_each = length(var.trusted_services) > 0 ? [1] : []
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = var.trusted_services
      }
    }
  }

  # Trust other IAM roles (cross-account or cross-service)
  dynamic "statement" {
    for_each = length(var.trusted_role_arns) > 0 ? [1] : []
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = var.trusted_role_arns
      }
    }
  }

  # Trust GitHub Actions via OIDC (no long-lived credentials needed)
  dynamic "statement" {
    for_each = length(var.github_oidc_subjects) > 0 ? [1] : []
    content {
      effect  = "Allow"
      actions = ["sts:AssumeRoleWithWebIdentity"]
      principals {
        type        = "Federated"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:aud"
        values   = ["sts.amazonaws.com"]
      }
      condition {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:sub"
        values   = var.github_oidc_subjects
      }
    }
  }
}

# ── IAM Role ──────────────────────────────────────────────────────────────────
resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.description
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = var.max_session_duration

  tags = merge(var.tags, { Name = var.role_name })
}

# ── Inline Policies ──────────────────────────────────────────────────────────
# Inline policies are embedded in the role and deleted when the role is deleted
resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

# ── Managed Policy Attachments ───────────────────────────────────────────────
# Attach AWS-managed policies (e.g., AmazonEKSClusterPolicy)
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# ── Instance Profile (needed if EC2 instances assume this role) ───────────────
resource "aws_iam_instance_profile" "this" {
  count = contains(var.trusted_services, "ec2.amazonaws.com") ? 1 : 0

  name = var.role_name
  role = aws_iam_role.this.name
  tags = var.tags
}
