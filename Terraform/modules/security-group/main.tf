# modules/security-group/main.tf
#
# PURPOSE: Reusable security group with dynamic ingress/egress rules.
#
# WHAT EVERY PLATFORM ENGINEER NEEDS TO KNOW:
# - Security groups are STATEFUL: if you allow inbound, the response is automatically allowed outbound
# - Use security group references (source_security_group_id) instead of CIDRs between your own services
#   e.g., "allow traffic from the web SG" instead of "allow traffic from 10.0.0.0/8"
#   This is more secure and doesn't break when IPs change
# - Never open 0.0.0.0/0 on SSH (port 22) or RDP (port 3389)

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    # Create new SG before destroying old one
    # Prevents downtime if the SG is attached to running instances
    create_before_destroy = true
  }
}

# ── Ingress Rules ─────────────────────────────────────────────────
resource "aws_security_group_rule" "ingress" {
  for_each = {
    for idx, rule in var.ingress_rules : "${rule.description}-${idx}" => rule
  }

  type              = "ingress"
  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol

  # Use either a CIDR block OR a source SG (not both)
  cidr_blocks              = each.value.source_security_group_id == null ? each.value.cidr_blocks : null
  source_security_group_id = each.value.source_security_group_id
}

# ── Egress Rules ──────────────────────────────────────────────────
resource "aws_security_group_rule" "egress" {
  for_each = {
    for idx, rule in var.egress_rules : "${rule.description}-${idx}" => rule
  }

  type              = "egress"
  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}
