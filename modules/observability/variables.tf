variable "vpc_id" {
  description = "VPC ID to enable VPC Flow Logs"
  type        = string
}

variable "flow_logs_name" {
  description = "Name tag for VPC Flow Logs"
  type        = string
  default     = "terraform-vpc-flow-logs"
}

variable "flow_logs_log_group_name" {
  description = "CloudWatch Logs log group name for VPC Flow Logs"
  type        = string
  default     = "/terraform-vpc-ec2-ssm/vpc-flow-logs"
}

variable "flow_logs_role_name" {
  description = "IAM role name for VPC Flow Logs"
  type        = string
  default     = "terraform-vpc-flow-logs-role"
}

variable "flow_logs_retention_in_days" {
  description = "Retention period in days for VPC Flow Logs"
  type        = number
  default     = 7
}

variable "traffic_type" {
  description = "Traffic type to capture. ACCEPT, REJECT, or ALL"
  type        = string
  default     = "ALL"
}