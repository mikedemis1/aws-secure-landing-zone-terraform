# Test fixture, not part of the product: a host in the private subnet used to
# prove that Session Manager works with no public IP, no SSH, no NAT.
# Off by default so a plain `apply` builds only the landing zone.

variable "create_test_host" {
  description = "Create a t3.micro in the first private subnet to prove SSM access. Demo only."
  type        = bool
  default     = false
}

# Latest AL2023 AMI from the public SSM parameter. SSM agent is preinstalled and
# the AMI is registered with IMDSv2 required. The value moves with every AL2023
# release and `ami` forces replacement; fine for apply-prove-destroy. In a
# long-lived stack, pin it or `ignore_changes = [ami]`.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "test" {
  count = var.create_test_host ? 1 : 0

  # insecure_value: the plain value is marked sensitive in provider 5.x and
  # would hide the AMI id in the plan output.
  ami                         = data.aws_ssm_parameter.al2023_ami.insecure_value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private[local.azs[0]].id
  vpc_security_group_ids      = [aws_security_group.private.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false
  # No key_name: there is no SSH path, by design.

  # IMDSv2 only. A token must be fetched with a PUT first, which SSRF and
  # proxy-style attacks generally cannot do. hop_limit = 1 keeps the token from
  # crossing a network hop (raise to 2 only for containers with bridge networking).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  # The host is useless before the endpoints exist: the agent would resolve
  # public IPs, find no route, and back off for minutes before retrying.
  depends_on = [aws_vpc_endpoint.ssm]

  tags = {
    Name = "${var.project_name}-ssm-test-host"
    Tier = "private"
  }
}

output "test_host_id" {
  value = one(aws_instance.test[*].id)
}
