output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public_1a.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private_1a.id
}

output "security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.no_inbound.id
}

output "vpc_endpoint_security_group_id" {
  description = "VPC endpoint security group ID"
  value       = aws_security_group.vpc_endpoint_sg.id
}

output "ssm_endpoint_id" {
  description = "SSM VPC endpoint ID"
  value       = aws_vpc_endpoint.ssm.id
}

output "ssmmessages_endpoint_id" {
  description = "SSM Messages VPC endpoint ID"
  value       = aws_vpc_endpoint.ssmmessages.id
}

output "ec2messages_endpoint_id" {
  description = "EC2 Messages VPC endpoint ID"
  value       = aws_vpc_endpoint.ec2messages.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "private_ip" {
  description = "EC2 private IP address"
  value       = aws_instance.web.private_ip
}

output "ssm_connect_command" {
  description = "Command to connect to EC2 via SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.web.id} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "stop_instance_command" {
  description = "Command to stop EC2 instance"
  value       = "aws ec2 stop-instances --instance-ids ${aws_instance.web.id} --region ${var.aws_region} --profile ${var.aws_profile}"
}