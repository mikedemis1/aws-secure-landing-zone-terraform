# The private tier has no route to the internet, so AWS services are reached
# through VPC endpoints instead of a NAT gateway: cheaper, and the traffic never
# leaves the VPC.
#
# Two kinds:
# - Interface endpoints (PrivateLink): an ENI with a private IP in each private
#   subnet that *is* the service. Needs a security group. Billed per hour + GB.
# - Gateway endpoint (S3, DynamoDB only): a route (prefix list) in the route
#   table. No ENI, no SG, free.

# Only the private tier may reach the endpoints. A security-group reference,
# not the VPC CIDR: the intent is "the private tier may use SSM", not "anything
# in this address range". A future public host gets its own ingress rule here.
# No egress rule needed: the endpoint only answers, and SGs are stateful.
resource "aws_security_group" "endpoints" {
  name        = "${var.project_name}-endpoints-sg"
  description = "VPC interface endpoints: HTTPS from the private tier only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-endpoints-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https_from_private" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from the private tier (SSM agent traffic)"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.private.id
}

# Session Manager needs all three:
# - ssm:         agent registration and UpdateInstanceInformation
# - ssmmessages: the session data channel (outbound WebSocket from the agent)
# - ec2messages: the Run Command delivery path; the agent still polls it
# private_dns_enabled rewrites ssm.<region>.amazonaws.com for the WHOLE VPC to
# the endpoint ENIs. Requires DNS support + hostnames on the VPC. With it off,
# the agent resolves public IPs, has no route, and never registers - silently.
locals {
  ssm_endpoint_services = toset(["ssm", "ssmmessages", "ec2messages"])
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = local.ssm_endpoint_services

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-${each.key}-endpoint"
  }
}

# S3 gateway endpoint on the private route tables. Covers the SSM agent's own
# update bucket and the AL2023 dnf repositories, which are served from S3.
# The default policy is Allow *, which means a private host can write to ANY
# S3 bucket in the world without internet access - an exfiltration channel.
# Left as-is here because restricting it would also block the AWS-owned
# AL2023/SSM buckets; in production, scope it with a policy.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}
