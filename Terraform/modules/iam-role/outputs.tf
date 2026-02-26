# modules/iam-role/outputs.tf

output "role_arn" {
  description = "ARN of the IAM role (use in trust policies and assume_role calls)"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "Unique ID of the IAM role"
  value       = aws_iam_role.this.unique_id
}

output "instance_profile_arn" {
  description = "ARN of the instance profile (for EC2 use)"
  value       = length(aws_iam_instance_profile.this) > 0 ? aws_iam_instance_profile.this[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the instance profile (for EC2 use)"
  value       = length(aws_iam_instance_profile.this) > 0 ? aws_iam_instance_profile.this[0].name : null
}
