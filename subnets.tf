# One public and one private subnet per availability zone, keyed by AZ name so
# that removing an AZ from the middle of the list does not shift the others
# (which `count` would do).

# "Public" means a route to the internet gateway exists, not that hosts are
# reachable. map_public_ip_on_launch stays false (the AWS default, stated
# explicitly): anything edge-facing requests its public address on purpose.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-public-${each.key}"
    Tier = "public"
  }
}

# Private by routing: no 0.0.0.0/0 route exists in this tier's route tables.
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${var.project_name}-private-${each.key}"
    Tier = "private"
  }
}
