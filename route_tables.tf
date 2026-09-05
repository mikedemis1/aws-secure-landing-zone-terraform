# One public route table for every public subnet: the internet gateway is
# VPC-scoped, so there is nothing zonal to isolate.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ, explicitly associated, carrying only the
# implicit local route. Two reasons:
# - Explicit over implicit: a subnet with no association falls back to the VPC
#   main route table, a default nobody owns.
# - Fault isolation: anything that would ever go into a private route (a NAT
#   gateway, most of all) is zonal. A shared table would turn an AZ-a failure
#   into an AZ-b blackhole. Route tables are free.
# The VPC main route table is left untouched and unused.
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
