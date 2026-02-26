# modules/s3-bucket/outputs.tf

output "bucket_id" {
  description = "Name (ID) of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket (use in IAM policies)"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name for the bucket (use for CloudFront origins)"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_region" {
  description = "AWS region where the bucket is located"
  value       = aws_s3_bucket.this.region
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on the bucket"
  value       = var.versioning_enabled
}
