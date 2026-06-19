output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public_1a.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.no_inbound.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.web.public_ip
}

output "private_ip" {
  description = "EC2 private IP address"
  value       = aws_instance.web.private_ip
}

output "ssm_connect_command" {
  description = "Command to connect to EC2 via SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.web.id} --region ap-northeast-1 --profile yoshihiro-admin"
}

output "stop_instance_command" {
  description = "Command to stop EC2 instance"
  value       = "aws ec2 stop-instances --instance-ids ${aws_instance.web.id} --region ap-northeast-1 --profile yoshihiro-admin"
}