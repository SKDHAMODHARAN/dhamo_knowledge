# modules/s3-bucket/main.tf
#
# PURPOSE: Creates a production-hardened S3 bucket with versioning,
# encryption, public access blocking, optional lifecycle rules.
#
# WHAT EVERY PLATFORM ENGINEER NEEDS TO KNOW:
# - S3 buckets must NEVER be public (unless serving static websites)
# - Versioning protects against accidental deletes
# - Encryption at rest is mandatory for compliance
# - Lifecycle rules save cost by moving cold data to cheaper storage classes

locals {
  use_kms = var.kms_key_arn != ""
}

# ── Core Bucket ──────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, { Name = var.bucket_name })

  lifecycle {
    # Prevent accidental deletion — remove this manually if you truly need to delete
    prevent_destroy = false   # Set to true in production configs
  }
}

# ── Block ALL public access ──────────────────────────────────────────────────
# This should ALWAYS be enabled unless the bucket is for static website hosting.
# A misconfigured S3 bucket is one of the most common data breach causes.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Versioning ───────────────────────────────────────────────────────────────
# Protects against accidental deletes and overwrites.
# Required for Terraform state buckets. Recommended for all production buckets.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# ── Encryption ───────────────────────────────────────────────────────────────
# SSE-KMS = customer-managed key (more control, costs $0.03/10K requests)
# SSE-S3  = AWS-managed key (simpler, free)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? var.kms_key_arn : null
    }
    bucket_key_enabled = local.use_kms   # Reduces KMS API costs by up to 99%
  }
}

# ── Lifecycle Rules ──────────────────────────────────────────────────────────
# Automatically move objects to cheaper storage or expire them.
# Common pattern: move to STANDARD_IA after 30d, GLACIER after 90d, delete after 365d
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "transition" {
        for_each = rule.value.transition_days != null ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      # Also expire old object versions when versioning is enabled
      dynamic "noncurrent_version_expiration" {
        for_each = var.versioning_enabled && rule.value.expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.expiration_days
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# ── CORS Configuration ────────────────────────────────────────────────────────
# Only needed if browsers upload directly to S3 (e.g., pre-signed URL uploads)
resource "aws_s3_bucket_cors_configuration" "this" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_origins = cors_rule.value.allowed_origins
      allowed_methods = cors_rule.value.allowed_methods
      allowed_headers = cors_rule.value.allowed_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# ── Access Logging ────────────────────────────────────────────────────────────
# Required for security audits and compliance (PCI-DSS, SOC2, HIPAA)
resource "aws_s3_bucket_logging" "this" {
  count = var.logging_bucket != "" ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_bucket
  target_prefix = "s3-access-logs/${var.bucket_name}/"
}

# ── Bucket Policy ─────────────────────────────────────────────────────────────
resource "aws_s3_bucket_policy" "this" {
  count = var.policy_json != "" ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = var.policy_json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
