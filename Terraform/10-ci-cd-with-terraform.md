# 10 — CI/CD with Terraform 🚀

> **The goal**: Nobody runs `terraform apply` from their laptop in production. Everything goes through the pipeline.

---

## Why CI/CD for Terraform?

```
❌ Without CI/CD:
  - Whoever has AWS credentials can apply changes
  - No review process for infrastructure changes
  - No audit trail of who ran what and when
  - Drift between what's in Git and what's in AWS
  - "Works on my machine" state issues

✅ With CI/CD:
  - Every change reviewed via Pull Request
  - Plan shown automatically on every PR
  - Apply only happens after merge to main
  - Full audit trail in Git history + pipeline logs
  - Consistent, reproducible deployments
```

---

## The Golden Pattern

```
Developer pushes code
        │
        ▼
  Pull Request opened
        │
        ▼
  CI: terraform fmt --check    ← Fail if code not formatted
  CI: terraform validate       ← Fail if syntax errors
  CI: tfsec scan               ← Fail if security issues
  CI: terraform plan           ← Show what would change
  CI: Post plan as PR comment  ← Team reviews the diff
        │
        ▼
  Team reviews plan in PR comment
        │
        ▼
  PR merged to main
        │
        ▼
  CD: terraform apply          ← Automatically applies plan
  CD: Notify Slack on success/failure
```

---

## GitHub Actions — Complete Workflow

### Structure

```
.github/
└── workflows/
    ├── terraform-plan.yml    ← Runs on Pull Request
    └── terraform-apply.yml   ← Runs on merge to main
```

### Plan Workflow (Pull Request)

```yaml
# .github/workflows/terraform-plan.yml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'          # Only run when TF files change
      - '.github/workflows/**'

permissions:
  id-token: write    # Required for OIDC auth with AWS
  contents: read
  pull-requests: write  # Required to post comments

env:
  TF_VERSION: "1.7.0"
  AWS_REGION: "us-east-1"
  WORKING_DIR: "terraform/environments/dev"

jobs:
  terraform-plan:
    name: Plan (${{ matrix.environment }})
    runs-on: ubuntu-latest

    strategy:
      matrix:
        environment: [dev, staging]   # Plan for multiple envs

    steps:
      # 1. Checkout code
      - name: Checkout
        uses: actions/checkout@v4

      # 2. Authenticate with AWS using OIDC (no long-lived credentials!)
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ${{ env.AWS_REGION }}

      # 3. Install Terraform
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      # 4. Format check — fail if code isn't formatted
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: terraform/

      # 5. Initialize
      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/${{ matrix.environment }}

      # 6. Validate syntax
      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform/environments/${{ matrix.environment }}

      # 7. Security scan
      - name: Security Scan
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: terraform/environments/${{ matrix.environment }}

      # 8. Plan and save output
      - name: Terraform Plan
        id: plan
        run: |
          terraform plan \
            -var-file="../../configs/${{ matrix.environment }}.tfvars" \
            -out=tfplan \
            -no-color 2>&1 | tee plan.txt
        working-directory: terraform/environments/${{ matrix.environment }}
        continue-on-error: true   # We'll show errors in the PR comment

      # 9. Post plan as PR comment
      - name: Post Plan Comment
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/environments/${{ matrix.environment }}/plan.txt', 'utf8');
            const planOutput = plan.length > 60000
              ? plan.substring(0, 60000) + '\n... (truncated)'
              : plan;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan — \`${{ matrix.environment }}\`\n\`\`\`hcl\n${planOutput}\n\`\`\``
            });

      # 10. Fail the job if plan failed
      - name: Check Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
```

### Apply Workflow (Merge to Main)

```yaml
# .github/workflows/terraform-apply.yml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

permissions:
  id-token: write
  contents: read

jobs:
  terraform-apply-dev:
    name: Apply Dev
    runs-on: ubuntu-latest
    environment: dev   # Uses GitHub Environment with required reviewers

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.DEV_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: us-east-1

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/dev

      - name: Terraform Apply
        run: terraform apply -auto-approve -var-file="../../configs/dev.tfvars"
        working-directory: terraform/environments/dev

  terraform-apply-prod:
    name: Apply Prod
    runs-on: ubuntu-latest
    needs: terraform-apply-dev          # Prod only runs AFTER dev succeeds
    environment: prod                   # Requires manual approval in GitHub

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.PROD_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: us-east-1

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7.0"

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/prod

      - name: Terraform Apply
        run: terraform apply -auto-approve -var-file="../../configs/prod.tfvars"
        working-directory: terraform/environments/prod
```

---

## OIDC Auth — No Long-Lived Credentials ✅

Never store AWS access keys in GitHub secrets. Use OIDC:

```hcl
# Terraform: Create the GitHub Actions IAM role
resource "aws_iam_role" "github_actions" {
  name = "GitHubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Only allow your specific repo
          "token.actions.githubusercontent.com:sub" = "repo:mycompany/terraform-platform:*"
        }
      }
    }]
  })
}
```

---

## GitOps Best Practices

```
Repository structure for CI/CD:
terraform-platform/
├── .github/workflows/
│   ├── terraform-plan.yml
│   └── terraform-apply.yml
├── terraform/
│   ├── modules/           ← Shared modules
│   │   ├── vpc/
│   │   └── eks/
│   ├── environments/
│   │   ├── dev/
│   │   └── prod/
│   └── configs/           ← .tfvars per environment
│       ├── dev.tfvars
│       └── prod.tfvars
└── README.md
```

**Branch protection rules** (configure in GitHub):
- Require PR reviews before merging
- Require CI checks to pass (plan must succeed)
- Require linear history
- Restrict who can push to `main`

**GitHub Environments** (configure for prod):
- Required reviewers for `prod` environment
- Wait timer before deploy (gives time to cancel)
- Only allow deploys from `main` branch

---

## ✅ Test Your Understanding

1. Why should `terraform apply` NEVER run from a developer's laptop in production?
2. What is OIDC authentication and why is it better than storing AWS_ACCESS_KEY_ID in GitHub Secrets?
3. In the apply workflow above, `terraform apply -auto-approve` is used. Why is that safe in CI/CD but dangerous locally?

> **Answers**: 1) No audit trail, depends on developer's local state/credentials, no peer review, risk of applying wrong changes or wrong environment. 2) OIDC creates short-lived, automatically rotating tokens via a trust relationship — no long-lived credentials to leak or manage. Keys in secrets can be copied, leaked, or forgotten. 3) In CI/CD, the plan was already reviewed and approved via PR. Apply runs the exact same code. Locally, -auto-approve skips the plan review step which is your last safety check before making real changes.

---

**Next**: [11 — Production Best Practices](./11-production-best-practices.md) → Everything that makes the difference between "it works" and "it's production-ready."
