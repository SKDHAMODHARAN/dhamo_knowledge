# modules/eks/main.tf
#
# PURPOSE: Creates an EKS cluster with IAM roles, managed node groups,
# OIDC provider (for IRSA), and CloudWatch control plane logging.
#
# WHAT EVERY PLATFORM ENGINEER NEEDS TO KNOW:
# - EKS cluster role = what the CONTROL PLANE can do (manage LBs, SGs etc.)
# - Node group role  = what WORKER NODES can do (pull ECR images, write logs)
# - IRSA (IAM Roles for Service Accounts) = pods get IAM permissions without instance metadata
#   → Pods assume IAM roles directly, much more secure than node-level roles
# - Always enable control plane logging — audit logs are essential for security

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── EKS Cluster IAM Role ──────────────────────────────────────────
# The cluster needs permissions to manage AWS resources on your behalf
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── EKS Node Group IAM Role ───────────────────────────────────────
data "aws_iam_policy_document" "node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = var.tags
}

# Required policies for EKS worker nodes
resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",         # VPC CNI plugin
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",  # Pull from ECR
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",          # Node-level metrics
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ── EKS Cluster ───────────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.cluster_security_group_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # Enable control plane logging — critical for security and debugging
  enabled_cluster_log_types = var.cluster_log_types

  tags = merge(var.tags, { Name = var.cluster_name })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  lifecycle {
    # Upgrading Kubernetes version is controlled — must be intentional
    ignore_changes = []
  }
}

# ── OIDC Provider for IRSA (IAM Roles for Service Accounts) ──────
# This allows pods to assume IAM roles directly without needing node-level permissions
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(var.tags, { Name = "${var.cluster_name}-oidc-provider" })
}

# ── Managed Node Groups ───────────────────────────────────────────
resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.node_subnet_ids

  instance_types = each.value.instance_types

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  disk_size = each.value.disk_size_gb

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Auto-update applies node security patches
  update_config {
    max_unavailable = 1   # At most 1 node unavailable during updates
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-${each.key}" })

  lifecycle {
    # Auto-scaler manages desired_size — don't let Terraform fight it
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node_policies]
}
