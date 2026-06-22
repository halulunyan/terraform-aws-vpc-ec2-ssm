terraform {
  backend "s3" {
    bucket         = "terraform-state-yoshihiro-941960167304-ap-northeast-1"
    key            = "terraform-aws-vpc-ec2-ssm/terraform.tfstate"
    region         = "ap-northeast-1"
    profile        = "yoshihiro-admin"
    dynamodb_table = "terraform-aws-vpc-ec2-ssm-locks"
    encrypt        = true
  }
}