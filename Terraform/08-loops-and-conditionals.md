# 08 — Loops & Conditionals 🔄

> **The power move**: Create 10 subnets across 3 AZs with 5 lines. Handle differences between environments with one-liners.

---

## Why Loops?

Without loops — copy paste hell:

```hcl
# ❌ BAD — what if you need 5 AZs?
resource "aws_subnet" "public_a" { cidr_block = "10.0.1.0/24" }
resource "aws_subnet" "public_b" { cidr_block = "10.0.2.0/24" }
resource "aws_subnet" "public_c" { cidr_block = "10.0.3.0/24" }
```

With loops — clean and scalable:

```hcl
# ✅ GOOD — add more AZs by just extending the list
resource "aws_subnet" "public" {
  count      = length(var.public_subnet_cidrs)
  cidr_block = var.public_subnet_cidrs[count.index]
}
```

---

## Method 1: `count` — Index-Based Loops

Best for: Creating N identical (or nearly identical) resources.

```hcl
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)   # Creates 3 subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]  # 0, 1, 2
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "public-subnet-${count.index + 1}" }
}

# Reference specific instances:
aws_subnet.public[0].id   # First subnet
aws_subnet.public[*].id   # All subnet IDs as a list
```

### Count for Conditional Creation

```hcl
variable "enable_bastion" {
  type    = bool
  default = false
}

# Create bastion only if enabled
resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0   # Either 0 or 1

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[0].id
}

# Reference it safely
output "bastion_ip" {
  value = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}
```

### Count Limitation ⚠️

If you **remove an item from the middle of a list**, count causes unexpected destroys:

```
Before: ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  → subnet[0] = 10.0.1.0/24
  → subnet[1] = 10.0.2.0/24  ← you remove this
  → subnet[2] = 10.0.3.0/24

After: ["10.0.1.0/24", "10.0.3.0/24"]
  → subnet[0] = 10.0.1.0/24
  → subnet[1] = 10.0.3.0/24  ← Terraform DESTROYS old [1] and recreates it
                                   Also DESTROYS [2] entirely
```

Solution: Use `for_each` instead.

---

## Method 2: `for_each` — Key-Based Loops ✅ Preferred for Most Cases

Best for: Creating resources from maps or sets where each has a unique identifier.

```hcl
# Using a map — keys make resources uniquely identifiable
variable "subnets" {
  type = map(object({
    cidr = string
    az   = string
    type = string
  }))
  default = {
    "public-a"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public" }
    "public-b"  = { cidr = "10.0.2.0/24", az = "us-east-1b", type = "public" }
    "private-a" = { cidr = "10.0.10.0/24", az = "us-east-1a", type = "private" }
    "private-b" = { cidr = "10.0.11.0/24", az = "us-east-1b", type = "private" }
  }
}

resource "aws_subnet" "all" {
  for_each = var.subnets   # key = "public-a", value = { cidr, az, type }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  map_public_ip_on_launch = each.value.type == "public"

  tags = {
    Name = each.key   # "public-a", "public-b", etc.
    Type = each.value.type
  }
}

# Reference individual resources by key:
aws_subnet.all["public-a"].id
aws_subnet.all["private-b"].cidr_block

# Get all IDs:
values(aws_subnet.all)[*].id
```

### for_each with a Set of Strings

```hcl
variable "security_group_rules" {
  type    = set(string)
  default = ["80", "443", "8080"]
}

resource "aws_security_group_rule" "ingress" {
  for_each = var.security_group_rules

  type              = "ingress"
  security_group_id = aws_security_group.main.id
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
```

---

## Method 3: `for` Expressions — Transforming Data

Use in locals or outputs to transform lists and maps:

```hcl
variable "instance_names" {
  default = ["web-1", "web-2", "web-3"]
}

# Transform a list into uppercase
locals {
  upper_names = [for name in var.instance_names : upper(name)]
  # Result: ["WEB-1", "WEB-2", "WEB-3"]
}

# Filter a list
locals {
  prod_only = [for env in ["dev", "prod", "staging"] : env if env == "prod"]
  # Result: ["prod"]
}

# Convert a list to a map
locals {
  subnet_map = { for subnet in aws_subnet.public : subnet.availability_zone => subnet.id }
  # Result: { "us-east-1a" = "subnet-123", "us-east-1b" = "subnet-456" }
}

# Map transformation
locals {
  tagged_cidrs = {
    for k, v in var.subnets : k => merge(v, { tagged = true })
  }
}
```

---

## Method 4: `dynamic` Blocks — Loops Inside Resources

Some resource arguments are blocks that need to repeat. Use `dynamic` for that.

```hcl
# Without dynamic — you'd have to hardcode every ingress rule
resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ✅ With dynamic — driven by a variable
variable "ingress_rules" {
  type = list(object({
    port        = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    { port = 80,  protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { port = 8080, protocol = "tcp", cidr_blocks = ["10.0.0.0/8"] },
  ]
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## Conditionals

```hcl
# Ternary operator: condition ? true_value : false_value

locals {
  instance_type     = var.environment == "prod" ? "r6g.large"  : "t3.micro"
  db_instance_class = var.environment == "prod" ? "db.r6g.xlarge" : "db.t3.micro"
  min_capacity      = var.environment == "prod" ? 3 : 1
}

resource "aws_db_instance" "main" {
  instance_class        = local.db_instance_class
  multi_az              = var.environment == "prod"
  deletion_protection   = var.environment == "prod"
  skip_final_snapshot   = var.environment != "prod"   # Skip in non-prod only
}
```

---

## Practical Example: Multi-AZ Setup

```hcl
variable "azs"             { default = ["us-east-1a", "us-east-1b", "us-east-1c"] }
variable "public_cidrs"    { default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] }
variable "private_cidrs"   { default = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"] }
variable "enable_nat_gw"   { default = true }

resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidrs[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = { Name = "private-${count.index + 1}" }
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gw ? length(var.azs) : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gw ? length(var.azs) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}
```

---

## When to Use What

| Scenario | Use |
|---|---|
| Create N identical resources | `count` |
| Create resources with unique keys | `for_each` |
| Remove mid-list without cascading destroys | `for_each` |
| Enable/disable a single resource | `count = var.enabled ? 1 : 0` |
| Transform a list/map in a local | `for` expression |
| Repeat blocks inside a resource | `dynamic` |

---

## ✅ Test Your Understanding

1. You have `count = length(var.subnet_cidrs)` creating 4 subnets. You remove the 2nd CIDR from the list. What happens to subnets 3 and 4?
2. When should you use `for_each` over `count`?
3. Rewrite this using `for_each` with a map so removing one subnet doesn't affect the others.

> **Answers**: 1) Terraform renumbers them — old subnet[2] becomes subnet[1], old subnet[3] becomes subnet[2]. The original subnet[2] and subnet[3] get destroyed and recreated. This is destructive and can cause downtime. 2) Use for_each when resources have unique identifiers (names, keys) and when you might need to remove items from the middle without cascading destroys. 3) Use a map with subnet names as keys — then removing one key only destroys that specific subnet.

---

**Next**: [09 — Security Best Practices](./09-security-best-practices.md) → Handle secrets, IAM, and least privilege in Terraform.
