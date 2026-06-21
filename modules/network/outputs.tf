output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public_1a.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private_1a.id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID"
  value       = aws_route_table.private.id
}

#output "nat_gateway_id" {
#  description = "NAT Gateway ID"
#  value       = aws_nat_gateway.main.id
#}

#output "nat_eip_public_ip" {
#  description = "NAT Gateway Elastic IP public IP"
#  value       = aws_eip.nat.public_ip
#}