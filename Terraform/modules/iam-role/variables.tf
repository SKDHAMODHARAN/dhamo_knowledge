# modules/iam-role/variables.tf

variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "description" {
  description = "Description of the IAM role"
  type        = string
  default     = ""
}

variable "trusted_services" {
  description = "AWS services that can assume this role (e.g. ['ec2.amazonaws.com', 'eks.amazonaws.com'])"
  type        = list(string)
  default     = []
}

variable "trusted_role_arns" {
  description = "IAM role ARNs that can assume this role (cross-account or cross-service)"
  type        = list(string)
  default     = []
}

variable "github_oidc_subjects" {
  description = "GitHub OIDC subjects for GitHub Actions (e.g. ['repo:mycompany/myrepo:*'])"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy name => policy JSON document"
  type        = map(string)
  default     = {}
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds (3600–43200)"
  type        = number
  default     = 3600
}

variable "tags" {
  type    = map(string)
  default = {}
}
