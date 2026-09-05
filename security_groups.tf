# Public tier: the only thing the internet can reach. Accepts HTTPS and nothing else.
resource "aws_security_group" "public" {
  name        = "${var.project_name}-public-sg"
  description = "Public tier: inbound HTTPS from the internet"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public_https_from_internet" {
  security_group_id = aws_security_group.public.id
  description       = "HTTPS from anywhere - the single internet-facing entry point"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# TODO(step 3): narrow to 443 -> private SG and 443 -> VPC endpoint SG once endpoints exist.
resource "aws_vpc_security_group_egress_rule" "public_all_outbound" {
  security_group_id = aws_security_group.public.id
  description       = "All outbound (to be narrowed once the private tier and SSM endpoints exist)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Private tier: application hosts. Reachable only from the public tier, only on 443.
# Membership-based source (security group, not CIDR): a host in the public subnet
# that does not carry the public SG still cannot reach this tier.
resource "aws_security_group" "private" {
  name        = "${var.project_name}-private-sg"
  description = "Private tier: inbound HTTPS from the public SG only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "private_https_from_public" {
  security_group_id            = aws_security_group.private.id
  description                  = "HTTPS from the public tier - the only flow into this tier (TLS end to end)"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.public.id
}

# The private subnet has no IGW/NAT route, so this rule is inert today. It is still
# a latent gap: the day a NAT gateway is added, full outbound becomes live.
# TODO(step 3): replace with 443 -> VPC endpoint SG (ssm, ssmmessages, ec2messages).
resource "aws_vpc_security_group_egress_rule" "private_all_outbound" {
  security_group_id = aws_security_group.private.id
  description       = "All outbound (inert without a NAT route; to be narrowed to SSM endpoints)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
