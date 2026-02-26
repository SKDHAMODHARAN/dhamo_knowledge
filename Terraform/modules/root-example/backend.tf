# modules/root-example/backend.tf
#
# PURPOSE: Configures remote state storage in S3 with DynamoDB locking.
#
# HOW TO USE:
# 1. Create the state bucket and DynamoDB table first (see 04-state-management.md)
# 2. Update bucket name, key, and region to match your environment
# 3. Run `terraform init` to initialize the backend
#
# In a real project, each environment (dev/staging/prod) would have
# its own backend.tf with a different `key` (state file path)

terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"          # ← Update this
    key            = "environments/dev/terraform.tfstate" # ← Different per environment
    region         = "us-east-1"
    dynamodb_table = "mycompany-terraform-locks"
    encrypt        = true
  }
}

# ---
# LEARNING NOTE: Backends can't use variables (Terraform limitation).
# That's why teams often use a script or CI/CD to inject backend config:
#
# terraform init \
#   -backend-config="bucket=${TF_STATE_BUCKET}" \
#   -backend-config="key=environments/${ENV}/terraform.tfstate" \
#   -backend-config="region=${AWS_REGION}"
