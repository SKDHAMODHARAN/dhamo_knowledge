# modules/root-example/outputs.tf
#
# PURPOSE: Expose key values after terraform apply for observability and
# for use by other systems (dashboards, CI/CD, other Terraform configs).

# ── Networking ────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID — reference this when creating resources in the same VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs — use for ALB, NAT Gateways"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs — use for EKS nodes, RDS, Lambda"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "NAT Gateway IPs — share with partners who need to allowlist your outbound IPs"
  value       = module.vpc.nat_gateway_public_ips
}

# ── EKS ──────────────────────────────────────────────────────────
output "eks_cluster_name" {
  description = "EKS cluster name — use in kubectl, Helm, and CI/CD pipelines"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint — use for kubectl config"
  value       = module.eks.cluster_endpoint
}

output "eks_connect_command" {
  description = "Run this command to connect kubectl to the cluster"
  value       = module.eks.kubeconfig_command
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN — use when creating IRSA IAM roles for pods"
  value       = module.eks.oidc_provider_arn
}

# ── RDS ──────────────────────────────────────────────────────────
output "db_host" {
  description = "RDS hostname — configure in application secrets (not hardcoded!)"
  value       = module.rds.db_host
}

output "db_port" {
  description = "RDS port"
  value       = module.rds.db_port
}

output "db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

# ── S3 ───────────────────────────────────────────────────────────
output "assets_bucket_name" {
  description = "S3 bucket name for application assets"
  value       = module.app_assets_bucket.bucket_id
}

output "assets_bucket_arn" {
  description = "S3 bucket ARN — use in IAM policies for access control"
  value       = module.app_assets_bucket.bucket_arn
}

# ── IAM ──────────────────────────────────────────────────────────
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions — add to OIDC config in GitHub"
  value       = module.github_actions_role.role_arn
}
