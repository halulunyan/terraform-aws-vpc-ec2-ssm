@"
# terraform-aws-vpc-ec2-ssm

TerraformでAWS上にVPC、パブリックサブネット、EC2、IAM Roleを作成し、SSHを使わずにSSM Session Managerで接続する検証環境です。

## 構成

- VPC
- Public Subnet
- Internet Gateway
- Route Table
- Security Group（インバウンドなし）
- EC2 Amazon Linux 2023
- IAM Role / Instance Profile
- AWS Systems Manager Session Manager 接続

## 特徴

この構成では、EC2にSSH接続用のキーペアを設定せず、Security Groupのインバウンドも開放しません。

EC2への接続は AWS Systems Manager Session Manager を利用します。

```text
Local PC
  ↓ aws ssm start-session
AWS Systems Manager
  ↓
EC2 Amazon Linux 2023
