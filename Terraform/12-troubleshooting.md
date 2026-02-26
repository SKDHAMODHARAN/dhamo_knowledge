# 12 — Troubleshooting 🔧

> **The skill that separates good engineers from great ones**: Debug Terraform problems methodically, not by randomly changing things.

---

## Debugging Mindset

```
When terraform apply fails:

1. READ the error message fully — don't skim it
2. Identify: is it a Terraform error or an AWS API error?
3. Check: did state get partially updated?
4. Fix one thing at a time
5. Always run `terraform plan` before re-applying
```

---

## Enable Verbose Logging

```bash
# Set log level (TRACE is most verbose)
export TF_LOG=DEBUG    # Options: TRACE, DEBUG, INFO, WARN, ERROR
export TF_LOG_PATH="terraform-debug.log"

terraform apply 2>&1 | tee apply.log

# Disable logging
unset TF_LOG
```

---

## Common Errors and Fixes

### Error 1: "Error acquiring the state lock"

```
Error: Error acquiring the state lock:
  ConditionalCheckFailedException: The conditional request failed
  Lock Info:
    ID:        abc-123
    Operation: OperationTypeApply
    Who:       user@company.com
    Created:   2024-01-15 09:30:00
```

**Cause**: A previous `terraform apply` crashed without releasing the lock.

```bash
# Force-release the lock (verify nobody else is running first!)
terraform force-unlock abc-123

# Verify the unlock
terraform state list   # Should work if lock is released
```

---

### Error 2: "Provider produced inconsistent result after apply"

```
Error: Provider produced inconsistent result after apply
  When applying changes to aws_security_group.main, provider produced an
  unexpected new value: Root object was present, but now absent.
```

**Cause**: AWS API returned a different value than Terraform expected, or a timing issue.

```bash
# Usually self-resolves on re-apply
terraform apply

# If persistent, refresh state first
terraform apply -refresh-only
terraform apply
```

---

### Error 3: "Error: Cycle detected"

```
Error: Cycle detected
  module.eks -> module.vpc -> module.eks
```

**Cause**: Circular dependency between resources.

```bash
# Visualize the dependency graph
terraform graph | dot -Tpng > graph.png

# Fix: break the cycle by using data sources instead of resource references
# Or by separating resources into different applies
```

---

### Error 4: "Resource already exists"

```
Error: error creating S3 Bucket: BucketAlreadyExists
  BucketName: mycompany-platform-logs
```

**Cause**: The resource was created outside Terraform or by a previous run that wasn't cleaned up.

```bash
# Option A: Import the existing resource into Terraform state
terraform import aws_s3_bucket.logs mycompany-platform-logs

# Option B: If you want Terraform to adopt it, import then plan
terraform import aws_s3_bucket.logs mycompany-platform-logs
terraform plan   # Should show no changes if your .tf matches

# Option C: If you DON'T want to manage it — use a different name in .tf
```

---

### Error 5: "Error: Invalid function argument"

```
Error: Invalid function argument
  Call to function "cidrsubnet" failed: prefix length not suitable for given
  address: prefix length 28 is too large for the specified address 10.0.0.0/16
```

**Cause**: Incorrect CIDR math.

```bash
# Use the Terraform console to test functions interactively
terraform console

> cidrsubnet("10.0.0.0/16", 8, 1)
"10.0.1.0/24"

> cidrsubnet("10.0.0.0/16", 8, 10)
"10.0.10.0/24"

> length(["a", "b", "c"])
3

# Ctrl+D to exit
```

---

### Error 6: "AccessDenied"

```
Error: error creating EC2 VPC: UnauthorizedOperation: You are not authorized
  to perform this operation.
  status code: 403, request id: abc-123
```

**Cause**: Terraform role/user doesn't have permission.

```bash
# Check who Terraform is authenticating as
aws sts get-caller-identity

# Check what role you're assuming
terraform plan 2>&1 | grep "AssumeRole"

# Verify the permission exists in IAM
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::123456789:role/TerraformRole" \
  --action-names "ec2:CreateVpc" \
  --resource-arns "*"
```

---

### Error 7: "terraform destroy" Blocked by `prevent_destroy`

```
Error: Instance cannot be destroyed
  Resource aws_db_instance.prod has lifecycle.prevent_destroy set,
  but the plan calls for this resource to be destroyed.
```

**Cause**: `prevent_destroy = true` is working as intended!

```bash
# If you INTENTIONALLY want to destroy it:
# 1. Remove prevent_destroy from the code + commit
# 2. Run terraform apply to update the lifecycle rule
# 3. THEN run terraform destroy or remove from .tf

# Never bypass this for production without approval!
```

---

## State Surgery — Advanced

### Remove a resource from state without deleting it in AWS

Use case: you want to stop Terraform managing a resource, or move it to another config.

```bash
# See what's in state
terraform state list

# Remove from state (AWS resource stays, Terraform forgets it)
terraform state rm aws_instance.old_web_server
```

### Import an existing resource

Use case: someone created a resource manually, now you want Terraform to manage it.

```bash
# 1. Write the resource block in .tf first (it must exist)
resource "aws_s3_bucket" "audit_logs" {
  bucket = "mycompany-audit-logs-prod"
}

# 2. Import the existing bucket into state
terraform import aws_s3_bucket.audit_logs mycompany-audit-logs-prod

# 3. Check for drift between your .tf and real resource
terraform plan
# If diffs exist, update your .tf to match real state, then re-plan
```

### Move resource in state (after renaming in .tf)

```bash
# If you don't use the moved {} block and rename manually:
terraform state mv \
  aws_security_group.web_servers \
  aws_security_group.web
```

### Replace a specific resource (force recreation)

```bash
# Force destroy + recreate of one resource
terraform apply -replace="aws_instance.web"

# Useful when: instance is in a bad state, you want a fresh one
# Without -replace: Terraform only recreates if attributes change
```

---

## Terraform Refresh vs Plan

```bash
# terraform refresh (DEPRECATED - don't use)
# Updates state to match real AWS state
# Dangerous: modifies state without showing you a diff first

# ✅ Use this instead:
terraform apply -refresh-only
# Shows what would change in state, requires approval
```

---

## Viewing State for Debugging

```bash
# List all resources in state
terraform state list

# Inspect a specific resource — shows all attributes
terraform state show aws_vpc.main

# Show full state as JSON (good for scripting)
terraform show -json | jq '.values.root_module.resources'

# Show outputs
terraform output
terraform output -json
```

---

## When terraform plan Shows Unexpected Destroy

```
# PAY ATTENTION when you see:
# -/+ (destroy then create) — this is disruptive
# - (destroy only) — data loss risk!

# Before panicking, check:
# 1. Did you rename a resource? Use moved {} block
# 2. Did a required attribute change that forces replacement?
#    (e.g. changing availability_zone on an EBS volume)
# 3. Did the provider change what constitutes "same" for a resource?
```

When you see a destroy that looks wrong:

```bash
# Get detailed diff to understand WHY Terraform wants to destroy
terraform plan -out=myplan
terraform show myplan | grep -A 20 "must be replaced"
```

---

## Terraform Debugging Cheatsheet

```bash
# What am I authenticated as?
aws sts get-caller-identity

# What Terraform version am I running?
terraform version

# Is state accessible?
terraform state list

# What does Terraform think is deployed?
terraform show

# What would change right now?
terraform plan

# What would change in state only (no resource changes)?
terraform plan -refresh-only

# Test HCL expressions interactively
terraform console

# Look at provider capabilities
terraform providers

# Full verbose log
TF_LOG=DEBUG terraform plan 2>&1 | head -200

# Graph dependencies
terraform graph | dot -Tsvg > graph.svg
```

---

## Common Mistake Patterns

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Plan wants to recreate everything | State file deleted or wrong backend | Restore state from S3 backup |
| "Resource already exists" error | Created outside Terraform | `terraform import` |
| Lock stuck | Previous crash | `terraform force-unlock <ID>` |
| Unexpected destroy on rename | Missing `moved {}` block | Add moved block before applying |
| Permissions error | IAM role missing permission | Update IAM policy for the Terraform role |
| Plan shows drift constantly | External processes modifying resources | Use `ignore_changes` for those attributes |
| `count` index errors | List length changed | Switch to `for_each` with maps |
| apply succeeds but resource wrong | Eventual consistency in AWS | Wait and re-plan, or add `depends_on` |

---

## ✅ Final Test — Scenario-Based

**Scenario 1**: You run `terraform plan` on prod and it shows it wants to destroy the production EKS cluster. You did NOT intend this. What are your first 3 actions?

**Scenario 2**: A colleague ran `terraform apply` from their laptop against prod (not through CI/CD). The apply failed partway. What is the state of the system and what do you do to recover?

**Scenario 3**: You need to rename `module.platform_vpc` to `module.vpc` in your code. How do you do this without destroying and recreating the VPC?

> **Answers**: 
> 1) Don't panic. 1: Run `terraform show` to see what state says about the cluster. 2: Check if you accidentally removed the cluster from your .tf files. 3: Check git diff to see what changed in the code recently. Find the cause before taking any action.
> 2) Partial state — some resources applied in AWS, state file was partially written. Run `terraform plan` to see the current diff. Fix the root cause (error). Run `terraform apply` again to complete the partial apply. Check for any duplicate or orphaned resources in AWS console.
> 3) Add `moved { from = module.platform_vpc, to = module.vpc }` to your code. Run `terraform plan` — it should show no destroys, just a state rename. Apply. Then you can safely remove the moved block in a future commit.

---

**🎉 Congratulations!** You have completed the Terraform learning path.

Return to the [README](./README.md) to review the full roadmap, then start applying what you've learned in the `modules/` folder.
