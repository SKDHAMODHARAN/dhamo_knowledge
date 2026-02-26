# modules/rds/main.tf
#
# PURPOSE: Creates a production-ready RDS instance with a subnet group,
# parameter group, automated backups, encryption, and storage autoscaling.
#
# WHAT EVERY PLATFORM ENGINEER NEEDS TO KNOW:
# - RDS must be in PRIVATE subnets — never publicly accessible
# - Multi-AZ creates a standby in another AZ (automatic failover ~60s)
# - Storage autoscaling prevents disk-full incidents silently growing storage
# - Automated backups give you point-in-time recovery up to 35 days
# - Never put raw passwords in Terraform code — use Secrets Manager or SSM

locals {
  # Map engine names to port numbers
  default_port = {
    postgres = 5432
    mysql    = 3306
    mariadb  = 3306
  }

  # Map engine names to cloudwatch log types
  engine_logs = {
    postgres = ["postgresql", "upgrade"]
    mysql    = ["error", "slowquery", "general"]
    mariadb  = ["error", "slowquery", "general"]
  }
}

# ── DB Subnet Group ───────────────────────────────────────────────
# Tells RDS which subnets it can use — must be in multiple AZs for Multi-AZ
resource "aws_db_subnet_group" "this" {
  name        = "${var.db_identifier}-subnet-group"
  description = "Subnet group for ${var.db_identifier}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.db_identifier}-subnet-group" })
}

# ── DB Parameter Group ────────────────────────────────────────────
# Use a custom parameter group rather than default — lets you change settings
resource "aws_db_parameter_group" "this" {
  name        = "${var.db_identifier}-params"
  family      = "${var.engine}${split(".", var.engine_version)[0]}"   # e.g. postgres15
  description = "Custom parameter group for ${var.db_identifier}"

  # Example: enable slow query logging for PostgreSQL
  dynamic "parameter" {
    for_each = var.engine == "postgres" ? [1] : []
    content {
      name  = "log_min_duration_statement"
      value = "1000"   # Log queries slower than 1000ms
    }
  }

  tags = merge(var.tags, { Name = "${var.db_identifier}-params" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── RDS Instance ──────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = var.db_identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage
  storage_type          = "gp3"             # gp3 is cheaper and faster than gp2
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage   # Enable autoscaling up to this value
  storage_encrypted     = true              # Always encrypt — no performance impact

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password   # Pass via SSM/Secrets Manager in production
  port     = local.default_port[var.engine]

  # Network
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = false   # NEVER true in production
  multi_az               = var.multi_az

  # Performance
  parameter_group_name         = aws_db_parameter_group.this.name
  performance_insights_enabled  = var.instance_class != "db.t2.micro"  # Not supported on t2.micro

  # Backups
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"      # UTC — during low-traffic hours
  maintenance_window      = "Sun:04:00-Sun:05:00"  # After backup window

  # Logging — all logs to CloudWatch
  enabled_cloudwatch_logs_exports = local.engine_logs[var.engine]

  # Protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.db_identifier}-final-${formatdate("YYYY-MM-DD", timestamp())}"

  # Auto minor version upgrades (security patches)
  auto_minor_version_upgrade = true
  apply_immediately          = false   # Apply changes during the next maintenance window

  tags = merge(var.tags, { Name = var.db_identifier })

  lifecycle {
    # Never let Terraform update the password — it's managed outside Terraform in prod
    ignore_changes = [password]
  }
}
