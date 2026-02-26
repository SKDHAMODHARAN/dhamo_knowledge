# modules/eks/variables.tf

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g. 1.29)"
  type        = string
  default     = "1.29"
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster (both public and private subnets)"
  type        = list(string)
}

variable "node_subnet_ids" {
  description = "Subnet IDs for worker nodes (private subnets recommended)"
  type        = list(string)
}

variable "cluster_security_group_ids" {
  description = "Additional security group IDs for the cluster API server"
  type        = list(string)
  default     = []
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint (within VPC)"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to access the public API endpoint (lock this down in prod!)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size_gb   = optional(number, 50)
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
}

variable "cluster_log_types" {
  description = "EKS control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
