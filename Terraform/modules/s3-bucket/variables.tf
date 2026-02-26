# modules/s3-bucket/variables.tf

variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning (required for state buckets, recommended for all prod buckets)"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow bucket deletion even if it contains objects (dangerous in prod!)"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for transitioning/expiring objects"
  type = list(object({
    id                       = string
    enabled                  = bool
    prefix                   = optional(string, "")
    transition_days          = optional(number, null)
    transition_storage_class = optional(string, "STANDARD_IA")
    expiration_days          = optional(number, null)
  }))
  default = []
}

variable "cors_rules" {
  description = "CORS rules (needed for browser-direct-upload scenarios)"
  type = list(object({
    allowed_origins = list(string)
    allowed_methods = list(string)
    allowed_headers = optional(list(string), ["*"])
    max_age_seconds = optional(number, 3600)
  }))
  default = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS encryption (leave empty for SSE-S3)"
  type        = string
  default     = ""
}

variable "logging_bucket" {
  description = "Bucket name for access logs (leave empty to disable logging)"
  type        = string
  default     = ""
}

variable "policy_json" {
  description = "Custom bucket policy JSON (leave empty to use default)"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
