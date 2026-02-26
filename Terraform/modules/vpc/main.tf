# modules/vpc/main.tf
#
# PURPOSE: Creates a production-ready VPC with public & private subnets,
# Internet Gateway, NAT Gateways (configurable), and route tables.
#
# WHAT EVERY PLATFORM ENGINEER NEEDS TO KNOW:
# - Public subnets: resources here get public IPs (ALB, bastion, NAT GW)
# - Private subnets: resources here have NO public IPs (EKS nodes, RDS)
# - NAT Gateway: lets private subnet resources reach the internet (e.g. pull Docker images)
# - One NAT GW per AZ = high availability (expensive)
# - One NAT GW total   = cheaper but single point of failure

locals {
  # How many NAT Gateways to create:
  # - If single_nat_gateway = true  → always 1 (cost saving, dev/staging)
  # - If single_nat_gateway = false → one per AZ (production HA)
  nat_gateway_count = var.enable_nat_gateway ? (
    var.single_nat_gateway ? 1 : length(var.availability_zones)
  ) : 0

  common_tags = merge(var.tags, {
    VpcName = var.vpc_name
  })
}

# ── VPC ─────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true   # Required for EKS, RDS endpoint resolution
  enable_dns_support   = true

  tags = merge(local.common_tags, { Name = var.vpc_name })
}

# ── Internet Gateway (public internet access) ────────────────────────────────
# Required for public subnets and as the route target for 0.0.0.0/0
resource "aws_internet_gateway" "this" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.vpc_name}-igw" })
}

# ── Public Subnets ──────────────────────────────────────────────────────────
# Resources in public subnets get public IPs automatically.
# Use for: ALB, bastion hosts, NAT Gateways
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true   # Auto-assign public IP to instances here

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-public-${count.index + 1}"
    Type = "public"
    # EKS needs these tags to discover public subnets for internet-facing LBs
    "kubernetes.io/role/elb" = "1"
  })
}

# ── Private Subnets ─────────────────────────────────────────────────────────
# Resources here have NO public IPs. Internet access only via NAT Gateway.
# Use for: EKS worker nodes, RDS, ElastiCache, Lambda
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  # map_public_ip_on_launch = false (default — correct for private subnets)

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-private-${count.index + 1}"
    Type = "private"
    # EKS needs these tags to discover private subnets for internal LBs
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ── Elastic IPs for NAT Gateways ─────────────────────────────────────────────
# Each NAT Gateway needs a static public IP
resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.vpc_name}-nat-eip-${count.index + 1}" })

  depends_on = [aws_internet_gateway.this]   # IGW must exist before EIP usable
}

# ── NAT Gateways ─────────────────────────────────────────────────────────────
# Placed in PUBLIC subnets — forwards traffic from private subnets to internet
resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id   # Must be in public subnet!

  tags = merge(local.common_tags, { Name = "${var.vpc_name}-nat-${count.index + 1}" })

  depends_on = [aws_internet_gateway.this]
}

# ── Route Table: Public Subnets ───────────────────────────────────────────────
# Routes 0.0.0.0/0 → Internet Gateway
resource "aws_route_table" "public" {
  count = length(var.public_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.common_tags, { Name = "${var.vpc_name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ── Route Tables: Private Subnets ─────────────────────────────────────────────
# Each private subnet routes 0.0.0.0/0 → NAT Gateway
# With single_nat_gateway=false: one route table per AZ (true HA)
# With single_nat_gateway=true:  all private subnets share one route table
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs) > 0 ? local.nat_gateway_count : 0

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id = aws_subnet.private[count.index].id
  # If single_nat_gateway: all private subnets use route_table[0]
  # If HA: subnet[i] uses route_table[i]
  route_table_id = aws_route_table.private[
    var.single_nat_gateway ? 0 : count.index
  ].id
}
