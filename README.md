# terraform-aws-vpc-ec2-ssm

TerraformでAWS上にVPC、Public Subnet、Private Subnet、EC2、IAM Role、VPC Endpointを作成し、Public IPやSSHを使わずに AWS Systems Manager Session Manager でPrivate Subnet上のEC2へ接続する検証環境です。

このリポジトリでは、単にAWSリソースを作成するだけでなく、Terraformの変数化、module化、GitHub Actionsによる自動チェック、module化後のapply、SSM接続確認までを一通り検証しています。

---

## 構成概要

この構成では、EC2をPrivate Subnetに配置し、外部からのSSH接続は行いません。

EC2にはPublic IPを付与せず、Security Groupのインバウンドも開放しません。
接続にはAWS Systems Manager Session Managerを使用し、SSM通信はInterface型VPC Endpoint経由で行います。

```text
Local PC
  |
  | aws ssm start-session
  v
AWS Systems Manager
  |
  | Interface VPC Endpoint
  v
Private Subnet
  |
  v
EC2 Amazon Linux 2023
```

---

## 作成される主なリソース

* VPC
* Public Subnet
* Private Subnet
* Internet Gateway
* Public Route Table
* Private Route Table
* Security Group

  * EC2用Security Group
  * VPC Endpoint用Security Group
* Interface VPC Endpoint

  * com.amazonaws.ap-northeast-1.ssm
  * com.amazonaws.ap-northeast-1.ssmmessages
  * com.amazonaws.ap-northeast-1.ec2messages
* EC2 Amazon Linux 2023
* IAM Role
* IAM Instance Profile
* EBS gp3 root volume

---

## ネットワーク構成

| 種別             |        CIDR | 用途                  |
| -------------- | ----------: | ------------------- |
| VPC            | 10.0.0.0/16 | 検証用VPC              |
| Public Subnet  | 10.0.1.0/24 | Internet Gateway接続用 |
| Private Subnet | 10.0.2.0/24 | EC2配置用              |

EC2はPrivate Subnetに配置されます。

```text
VPC: 10.0.0.0/16
├─ Public Subnet: 10.0.1.0/24
│  └─ Internet Gatewayへのルートあり
└─ Private Subnet: 10.0.2.0/24
   ├─ EC2
   └─ SSM用VPC Endpoint
```

---

## セキュリティ方針

この検証環境では、EC2に対する直接のインバウンド接続を許可しません。

* EC2にPublic IPを付与しない
* SSHキーペアを使用しない
* Security Groupのインバウンドを開放しない
* EC2接続はSSM Session Managerを使用する
* EC2にはSSM接続用のIAM Roleを付与する
* IMDSv2を必須化する
* EBS root volumeを暗号化する

---

## VPC Endpoint

Private Subnet上のEC2がSSMと通信できるように、以下のInterface VPC Endpointを作成します。

| Endpoint    | 用途                       |
| ----------- | ------------------------ |
| ssm         | Systems Manager API通信用   |
| ssmmessages | Session Managerのメッセージ通信用 |
| ec2messages | SSM AgentとAWS間のメッセージ通信用  |

VPC Endpoint用Security Groupでは、VPC CIDRからのHTTPS通信のみ許可します。

---

## EC2設定

EC2はAmazon Linux 2023を使用します。AMIはTerraformのdata sourceで最新のAmazon Linux 2023 AMIを取得します。

主な設定は以下です。

* Instance Type: t3.micro
* Subnet: Private Subnet
* Public IP: なし
* Security Group: インバウンドなし
* IAM Role: AmazonSSMManagedInstanceCore
* Root Volume: gp3 / 30GiB / encrypted
* IMDSv2: required

---

## Terraformファイル構成

```text
.
├─ main.tf
├─ variables.tf
├─ outputs.tf
├─ terraform.tfvars.example
├─ .gitignore
├─ README.md
├─ modules/
│  ├─ network/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  └─ outputs.tf
│  └─ iam/
│     ├─ main.tf
│     ├─ variables.tf
│     └─ outputs.tf
├─ docs/
│  ├─ architecture.md
│  ├─ interview-notes.md
│  └─ terraform-learning-log.md
└─ .github/
   └─ workflows/
      └─ terraform.yml
```

---

## Terraform module構成

このリポジトリでは、Terraform moduleを以下の考え方で整理しています。

```text
variables.tf = 引数
main.tf      = 処理本体
outputs.tf   = 戻り値
```

### root main.tf

rootの `main.tf` は、全体の構成を組み立てる役割です。

```text
root main.tf
  ├─ provider
  ├─ module "network"
  ├─ module "iam"
  ├─ Security Group
  ├─ VPC Endpoint
  ├─ AMI data
  └─ EC2
```

### modules/network

`modules/network` では、ネットワーク関連リソースを作成します。

```text
modules/network
  ├─ VPC
  ├─ Public Subnet
  ├─ Private Subnet
  ├─ Internet Gateway
  ├─ Public Route Table
  └─ Private Route Table
```

root側では以下のように呼び出します。

```hcl
module "network" {
  source = "./modules/network"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}
```

module内で作成したVPCやSubnetは、root側から以下のように参照します。

```hcl
vpc_id    = module.network.vpc_id
subnet_id = module.network.private_subnet_id
```

### modules/iam

`modules/iam` では、EC2がSSM Session Managerを利用するためのIAM関連リソースを作成します。

```text
modules/iam
  ├─ IAM Role
  ├─ Policy Attachment
  └─ Instance Profile
```

root側では以下のように呼び出します。

```hcl
module "iam" {
  source = "./modules/iam"

  role_name             = "terraform-ec2-ssm-role"
  instance_profile_name = "terraform-ec2-ssm-profile"
}
```

EC2側では、IAM Instance Profileを以下のように参照します。

```hcl
iam_instance_profile = module.iam.instance_profile_name
```

---

## 変数

主な変数は `variables.tf` で管理します。

| 変数名                 | デフォルト値                | 説明                  |
| ------------------- | --------------------- | ------------------- |
| aws_region          | ap-northeast-1        | AWSリージョン            |
| aws_profile         | yoshihiro-admin       | AWS CLIプロファイル       |
| project_name        | terraform-vpc-ec2-ssm | プロジェクト名             |
| vpc_cidr            | 10.0.0.0/16           | VPC CIDR            |
| public_subnet_cidr  | 10.0.1.0/24           | Public Subnet CIDR  |
| private_subnet_cidr | 10.0.2.0/24           | Private Subnet CIDR |
| availability_zone   | ap-northeast-1a       | Availability Zone   |
| instance_type       | t3.micro              | EC2インスタンスタイプ        |
| root_volume_size    | 30                    | EBS root volumeサイズ  |

実環境用の値は `terraform.tfvars` に記載します。
`terraform.tfvars` はGit管理対象外とし、代わりに `terraform.tfvars.example` をサンプルとして管理します。

---

## 使い方

### 1. AWS SSOログイン

このリポジトリではAWS CLI profileとして `yoshihiro-admin` を利用します。

Terraform実行前にSSOログインします。

```powershell
aws sso login --profile yoshihiro-admin
```

認証確認：

```powershell
aws sts get-caller-identity --profile yoshihiro-admin
```

### 2. 初期化

```powershell
terraform init
```

### 3. フォーマット

```powershell
terraform fmt
```

### 4. 構文チェック

```powershell
terraform validate
```

### 5. 実行計画確認

```powershell
terraform plan
```

### 6. 作成

```powershell
terraform apply
```

---

## SSM接続

Terraform apply後、以下のoutputでSSM接続コマンドを確認できます。

```powershell
terraform output -raw ssm_connect_command
```

表示されたコマンドを実行します。

```powershell
aws ssm start-session --target <instance-id> --region ap-northeast-1 --profile yoshihiro-admin
```

接続できると、以下のようなシェルに入ります。

```text
Starting session with SessionId: ...
sh-5.2$
```

---

## 接続確認

SSM管理対象としてOnlineになっているか確認します。

```powershell
aws ssm describe-instance-information `
  --region ap-northeast-1 `
  --profile yoshihiro-admin `
  --query "InstanceInformationList[*].[InstanceId,PingStatus,PlatformName]" `
  --output table
```

期待値：

```text
InstanceId              PingStatus  PlatformName
i-xxxxxxxxxxxxxxxxx     Online      Amazon Linux
```

VPC Endpointの状態確認：

```powershell
aws ec2 describe-vpc-endpoints `
  --region ap-northeast-1 `
  --profile yoshihiro-admin `
  --filters "Name=vpc-id,Values=<vpc-id>" `
  --query "VpcEndpoints[*].[ServiceName,State,PrivateDnsEnabled]" `
  --output table
```

期待値：

```text
com.amazonaws.ap-northeast-1.ssm           available  True
com.amazonaws.ap-northeast-1.ssmmessages   available  True
com.amazonaws.ap-northeast-1.ec2messages   available  True
```

---

## GitHub Actions

このリポジトリでは、GitHub ActionsでTerraformコードの自動チェックを行います。

設定ファイル：

```text
.github/workflows/terraform.yml
```

push時に以下を自動実行します。

```text
terraform fmt -check -recursive
terraform init
terraform validate
```

現時点では安全性を優先し、GitHub Actionsから `terraform apply` は実行しません。

```text
GitHub Actions
  → fmt / init / validate の自動チェック

terraform apply
  → ローカル環境から手動実行
```

---

## EC2停止

検証後、EC2を停止する場合は以下を実行します。

```powershell
terraform output -raw stop_instance_command
```

表示されたコマンドを実行します。

```powershell
aws ec2 stop-instances --instance-ids <instance-id> --region ap-northeast-1 --profile yoshihiro-admin
```

---

## 削除

検証環境を削除する場合は以下を実行します。

```powershell
terraform destroy
```

この構成ではEC2を停止しても、VPC EndpointやEBSなど一部リソースには課金が発生する可能性があります。
検証が終わった環境を完全に削除する場合は `terraform destroy` を実行します。

---

## 学習ポイント

このリポジトリでは、以下を学習目的としています。

* TerraformによるAWSリソース作成
* VPC / Subnet / Route Table / Internet Gatewayの基本構成
* Public SubnetとPrivate Subnetの違い
* Security Groupでインバウンドを開けない構成
* IAM Role / Instance ProfileによるEC2権限付与
* SSM Session ManagerによるEC2接続
* Interface VPC EndpointによるPrivate SubnetからのAWS API接続
* IMDSv2必須化
* EBS暗号化
* Terraform outputsの活用
* Terraform module化
* GitHubによるTerraformコード管理
* GitHub ActionsによるTerraform自動チェック

# terraform-aws-vpc-ec2-ssm

Terraformを使用して、AWS上にPrivate Subnet配置のEC2と、SSM Session ManagerおよびCloudWatch Logs用のVPC Endpointを構築する検証リポジトリです。

## 構成概要

この構成では、EC2インスタンスをPrivate Subnetに配置し、Public IPを付与せず、Security GroupのInboundも開放しません。

管理アクセスはSSHではなく、AWS Systems Manager Session Managerを利用します。

また、CloudWatch AgentをEC2にインストールし、ログファイルをCloudWatch Logsへ送信します。

## 作成する主なリソース

- VPC
- Public Subnet
- Private Subnet
- Internet Gateway
- Public Route Table
- Private Route Table
- EC2 Instance
- Security Group
  - EC2用: Inboundなし
  - VPC Endpoint用: VPC CIDRから443許可
- IAM Role / Instance Profile
  - AmazonSSMManagedInstanceCore
  - CloudWatchAgentServerPolicy
- Interface VPC Endpoint
  - ssm
  - ssmmessages
  - ec2messages
  - logs

## 検証したこと

### 1. SSM Session Manager接続

Private Subnet上のEC2に対して、以下の条件でSSM接続できることを確認しました。

- Public IPなし
- SSHなし
- 22番ポート開放なし
- Security Group Inboundなし
- 踏み台サーバなし

SSM接続は以下のVPC Endpoint経由で実現しています。

- ssm
- ssmmessages
- ec2messages

### 2. CloudWatch Logs送信

CloudWatch AgentをEC2にインストールし、以下のログをCloudWatch Logsへ送信できることを確認しました。

- `/tmp/cwagent-test.log`
- `/var/log/dnf.log`

CloudWatch Logs送信は以下のVPC Endpoint経由で実現しています。

- logs

### 3. NAT Gatewayなしでの閉域検証

一時的にNAT Gatewayを作成し、Private Subnetから外部リポジトリへ到達できることを確認しました。

その後、Private Route Tableから `0.0.0.0/0 -> NAT Gateway` のルートを削除し、さらにNAT Gateway本体とElastic IPも削除しました。

NAT Gateway削除後、以下を確認しました。

- SSM接続は継続可能
- CloudWatch Logs送信は継続可能
- `curl https://aws.amazon.com` はtimeout
- 一般インターネット通信は不可

これにより、NAT GatewayとVPC Endpointの役割分担を確認しました。

## 役割分担

| 通信内容                              | 必要な仕組み                                       |
| --------------------------------- | -------------------------------------------- |
| Private EC2から一般インターネットへ出る         | NAT Gateway / Proxyなど                        |
| Private EC2からSSMへ接続する             | ssm / ssmmessages / ec2messages VPC Endpoint |
| Private EC2からCloudWatch Logsへ送信する | logs VPC Endpoint                            |

## 実行コマンド

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

> `terraform apply` を実行するとAWSリソースが作成され、利用状況に応じて料金が発生します。事前に `terraform plan` の内容を確認してください。

---

## 学習ログ

Terraform module化、GitHub Actionsによる自動チェック、module化後のapply、SSM Session Manager接続確認までの詳細は以下に整理しています。

* [Terraform Learning Log](docs/terraform-learning-log.md)

---

## 関連ドキュメント

* [Architecture](docs/architecture.md)
* [Interview Notes](docs/interview-notes.md)
* [Terraform Learning Log](docs/terraform-learning-log.md)
