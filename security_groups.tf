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

# The only place the public tier sends traffic: the private tier, on 443.
# No rule to the SSM endpoints: the endpoint SG does not admit the public SG,
# so such a rule would match nothing. When a public host is built, add both
# sides (endpoints-sg ingress from public-sg, public-sg egress to endpoints-sg).
resource "aws_vpc_security_group_egress_rule" "public_https_to_private" {
  security_group_id            = aws_security_group.public.id
  description                  = "HTTPS to the private tier - the only outbound flow"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.private.id
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

# Egress encodes intent, not just what the route table happens to allow today:
# the private tier talks to the SSM endpoints and to S3 through the gateway
# endpoint, and nothing else. If a NAT gateway is ever added, this still holds.
# IMDS, the VPC DNS resolver and Amazon Time Sync are link-local and exempt
# from SG evaluation, so they keep working.
resource "aws_vpc_security_group_egress_rule" "private_https_to_endpoints" {
  security_group_id            = aws_security_group.private.id
  description                  = "HTTPS to the SSM interface endpoints (agent registration and session channel)"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoints.id
}

resource "aws_vpc_security_group_egress_rule" "private_https_to_s3" {
  security_group_id = aws_security_group.private.id
  description       = "HTTPS to S3 via the gateway endpoint (SSM agent updates, AL2023 dnf repos)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}
