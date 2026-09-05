# What the next layer needs: interface endpoints want one private subnet per AZ,
# a gateway endpoint attaches to the private route tables, endpoint SGs need the
# VPC CIDR. Reaching into resource internals instead would turn the layout into
# one big file.

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "az_names" {
  description = "Per-account AZ aliases in use."
  value       = local.azs
}

output "az_ids" {
  description = "Physical zone IDs for the AZs in use; stable across accounts."
  value       = slice(data.aws_availability_zones.available.zone_ids, 0, var.az_count)
}

output "public_subnet_ids" {
  value = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnet_ids" {
  value = { for az, s in aws_subnet.private : az => s.id }
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_ids" {
  value = { for az, rt in aws_route_table.private : az => rt.id }
}

output "log_bucket_name" {
  value = aws_s3_bucket.logs.id
}
