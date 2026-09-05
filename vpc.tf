resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Both are required by VPC interface endpoints with private DNS (the SSM path
  # for private hosts). Do not "clean up".
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Every VPC ships with a default security group that allows all egress and all
# ingress from itself. Adopting it with no rules strips them, so nothing can run
# on implicit network permissions: every workload gets a purpose-built SG.
# (CIS AWS Foundations: the default SG of every VPC restricts all traffic.)
resource "aws_default_security_group" "locked" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-default-sg-locked"
  }
}

# AZ names are per-account aliases (this account's eu-west-1a may be another
# account's eu-west-1c). Zone IDs (euw1-az1) are the physical identifier and are
# exposed as an output for that reason.
data "aws_availability_zones" "available" {
  state = "available"

  # Keeps opted-in Local/Wavelength zones out of the list. eu-west-1 has none
  # today; the filter documents the assumption.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /24 slots inside the VPC: 0-9 public, 10-19 private. The gap leaves room for
  # more AZs per tier, and for a third tier at offset 20, without renumbering.
  public_offset  = 0
  private_offset = 10

  public_subnets  = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, local.public_offset + i) }
  private_subnets = { for i, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, local.private_offset + i) }
}
