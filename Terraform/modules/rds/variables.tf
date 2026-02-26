# modules/rds/variables.tf

variable "db_identifier" {
  description = "Unique identifier for the RDS instance"
  type        = string
}

variable "engine" {
  description = "Database engine (postgres, mysql, mariadb)"
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["postgres", "mysql", "mariadb"], var.engine)
    error_message = "engine must be postgres, mysql, or mariadb."
  }
}

variable "engine_version" {
  description = "Database engine version (e.g. 15.4 for Postgres)"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "RDS instance type (e.g. db.t3.micro, db.r6g.large)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling (0 to disable)"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the initial database to create"
  type        = string
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password (use SSM/Secrets Manager in production — never hardcode!)"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs for the RDS instance"
  type        = list(string)
}

variable "multi_az" {
  description = "Enable Multi-AZ for high availability (true for prod)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days to retain automated backups (0 = disabled, max 35)"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection (always true in prod)"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (set false in prod)"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
