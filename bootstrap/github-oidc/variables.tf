variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "yoshihiro-admin"
}

variable "github_owner" {
  description = "GitHub owner or organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch name"
  type        = string
  default     = "main"
}

variable "role_name" {
  description = "IAM role name for GitHub Actions Terraform plan"
  type        = string
  default     = "github-actions-terraform-plan-role"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
}

variable "state_key_prefix" {
  description = "S3 key prefix for Terraform state"
  type        = string
}