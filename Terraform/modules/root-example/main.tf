# modules/root-example/main.tf
#
# PURPOSE: Demonstrates how to wire all modules together in a real project.
#          This is the pattern used in production platform engineering repos.
#
# READ THIS FILE TOP-TO-BOTTOM and understand how each module feeds into the next:
#
#   VPC (networking)
#    └─► security-group (who can talk to what)
#         └─► RDS (database — needs VPC subnets + security group)
#         └─► EKS (Kubernetes — needs VPC subnets)
#    └─► S3 (object storage — no VPC dependency, but IAM role attached)
#    └─► IAM role (GitHub Actions CI/CD role)
#
# MENTAL MODEL: Always provision bottom-up (foundation first):
#   1. Networking (VPC)
#   2. Security (SGs, IAM)
#   3. Data layer (RDS, S3)
#   4. Compute (EKS)
#   5. Application (Helm charts, K8s manifests)

locals {
  # Single source of truth for all resource names
  name_prefix = "${var.project_name}-${var.environment}"

  # Determine dev vs prod behavior
  is_prod = var.environment == "prod"

  # RDS instance sizes per environment
  rds_instance_class = {
    dev     = "db.t3.micro"
    staging = "db.t3.medium"
    prod    = "db.r6g.large"
  }

  # EKS node sizes per environment
  eks_instance_types = {
    dev     = ["t3.medium"]
    staging = ["t3.large"]
    prod    = ["m6i.xlarge"]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. NETWORKING: VPC, Subnets, NAT Gateways
# This is the foundation everything else lives in.
# ─────────────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../vpc"

  vpc_name             = "${local.name_prefix}-vpc"
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway = true
  # Dev: single NAT GW saves ~$32/month
  # Prod: one per AZ for HA
  single_nat_gateway = !local.is_prod
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. SECURITY GROUPS: Control traffic between services
# ─────────────────────────────────────────────────────────────────────────────

# Web/ALB security group — accepts HTTPS from internet
module "alb_sg" {
  source = "../security-group"

  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      description = "HTTPS from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTP from internet (redirect to HTTPS)"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# EKS node security group — receives traffic from ALB only
module "eks_node_sg" {
  source = "../security-group"

  name        = "${local.name_prefix}-eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      description              = "Traffic from ALB"
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
}

# RDS security group — receives traffic from EKS nodes only
module "rds_sg" {
  source = "../security-group"

  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS — allows access from EKS nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      description              = "Postgres from EKS nodes"
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = module.eks_node_sg.security_group_id
    }
  ]

  egress_rules = []   # No outbound needed for databases
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. STORAGE: S3 Bucket for application assets / logs
# ─────────────────────────────────────────────────────────────────────────────
module "app_assets_bucket" {
  source = "../s3-bucket"

  bucket_name        = "${local.name_prefix}-app-assets-${data.aws_caller_identity.current.account_id}"
  versioning_enabled = local.is_prod   # Only enable versioning in prod
  force_destroy      = !local.is_prod  # Allow cleanup in dev, protect in prod

  lifecycle_rules = local.is_prod ? [
    {
      id                       = "archive-old-assets"
      enabled                  = true
      prefix                   = "logs/"
      transition_days          = 30
      transition_storage_class = "STANDARD_IA"
      expiration_days          = 365
    }
  ] : []

  tags = { Purpose = "Application Assets" }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. IAM: GitHub Actions role for CI/CD deployments
# ─────────────────────────────────────────────────────────────────────────────
module "github_actions_role" {
  source = "../iam-role"

  role_name   = "${local.name_prefix}-github-actions"
  description = "Role assumed by GitHub Actions for deploying to ${var.environment}"

  # GitHub Actions OIDC — no long-lived credentials needed
  github_oidc_subjects = [
    "repo:mycompany/terraform-platform:environment:${var.environment}"
  ]

  # Inline policy — least privilege for what CI/CD needs
  inline_policies = {
    "eks-deploy" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["eks:DescribeCluster", "eks:ListClusters"]
          Resource = module.eks.cluster_arn
        },
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject"]
          Resource = "${module.app_assets_bucket.bucket_arn}/*"
        }
      ]
    })
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. DATABASE: RDS PostgreSQL
# ─────────────────────────────────────────────────────────────────────────────
module "rds" {
  source = "../rds"

  db_identifier  = "${local.name_prefix}-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = local.rds_instance_class[var.environment]

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password   # Set via TF_VAR_db_password or Secrets Manager

  # Network — always private subnets and scoped security group
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  # HA and protection scale with environment
  multi_az                = local.is_prod
  backup_retention_period = local.is_prod ? 14 : 1
  deletion_protection     = local.is_prod
  skip_final_snapshot     = !local.is_prod

  tags = { Component = "database" }
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. COMPUTE: EKS Cluster
# ─────────────────────────────────────────────────────────────────────────────
module "eks" {
  source = "../eks"

  cluster_name       = "${local.name_prefix}-eks"
  kubernetes_version = var.kubernetes_version

  # Both public and private subnets needed so control plane can talk to nodes
  subnet_ids      = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids = module.vpc.private_subnet_ids   # Nodes in private subnets only

  # Control plane network access
  endpoint_private_access = true
  endpoint_public_access  = !local.is_prod  # Disable public access in prod
  public_access_cidrs     = local.is_prod ? ["10.0.0.0/8"] : ["0.0.0.0/0"]

  node_groups = {
    "general" = {
      instance_types = local.eks_instance_types[var.environment]
      min_size       = local.is_prod ? 2 : 1
      max_size       = local.is_prod ? 10 : 3
      desired_size   = local.is_prod ? 3 : 1
      disk_size_gb   = 50
      labels         = { role = "general" }
      taints         = []
    }
  }
}

# Needed for IAM OIDC lookups
data "aws_caller_identity" "current" {}
