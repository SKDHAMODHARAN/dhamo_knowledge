# modules/root-example/terraform.tf
#
# PURPOSE: Configures Terraform version and providers for this example.
# In a real project, every environment (dev/staging/prod) would have its own
# version of this file pointing to different backend state paths.

terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Apply these tags to EVERY resource created by this config
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = var.environment
      Repository  = "github.com/mycompany/terraform-platform"
      Team        = "platform-engineering"
    }
  }
}
