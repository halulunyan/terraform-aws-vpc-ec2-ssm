output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.ec2_ssm_role.name
}

output "role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.ec2_ssm_role.arn
}

output "instance_profile_name" {
  description = "IAM instance profile name"
  value       = aws_iam_instance_profile.ec2_ssm_profile.name
}

output "instance_profile_arn" {
  description = "IAM instance profile ARN"
  value       = aws_iam_instance_profile.ec2_ssm_profile.arn
}