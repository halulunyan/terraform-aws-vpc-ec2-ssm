terraform {
  backend "s3" {
    bucket       = "terraform-state-yoshihiro-941960167304-ap-northeast-1"
    key          = "terraform-aws-vpc-ec2-ssm/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}