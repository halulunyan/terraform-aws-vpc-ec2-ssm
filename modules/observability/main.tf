resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = var.flow_logs_log_group_name
  retention_in_days = var.flow_logs_retention_in_days

  tags = {
    Name    = var.flow_logs_log_group_name
    Purpose = "vpc-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = var.flow_logs_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = var.flow_logs_role_name
    Purpose = "vpc-flow-logs"
  }
}

resource "aws_iam_policy" "vpc_flow_logs" {
  name = "${var.flow_logs_role_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.vpc_flow_logs.arn,
          "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
        ]
      }
    ]
  })

  tags = {
    Name    = "${var.flow_logs_role_name}-policy"
    Purpose = "vpc-flow-logs"
  }
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs" {
  role       = aws_iam_role.vpc_flow_logs.name
  policy_arn = aws_iam_policy.vpc_flow_logs.arn
}

resource "aws_flow_log" "vpc" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  traffic_type         = var.traffic_type
  vpc_id               = var.vpc_id

  max_aggregation_interval = 60

  tags = {
    Name    = var.flow_logs_name
    Purpose = "vpc-flow-logs"
  }

  depends_on = [
    aws_iam_role_policy_attachment.vpc_flow_logs
  ]
}