variable "role_name" {
  description = "IAM role name for EC2 SSM access"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for EC2"
  type        = string
}