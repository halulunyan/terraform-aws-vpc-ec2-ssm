# terraform-aws-vpc-ec2-ssm

TerraformでAWS上にVPC、Public Subnet、Private Subnet、EC2、IAM Role、VPC Endpointを作成し、Public IPやSSHを使わずにAWS Systems Manager Session ManagerでPrivate Subnet上のEC2へ接続する検証環境です。

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
  | VPC Endpoint
  v
Private Subnet
  |
  v
EC2 Amazon Linux 2023
```

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

## セキュリティ方針

この検証環境では、EC2に対する直接のインバウンド接続を許可しません。

* EC2にPublic IPを付与しない
* SSHキーペアを使用しない
* Security Groupのインバウンドを開放しない
* EC2接続はSSM Session Managerを使用する
* EC2にはSSM接続用のIAM Roleを付与する
* IMDSv2を必須化する
* EBS root volumeを暗号化する

## VPC Endpoint

Private Subnet上のEC2がSSMと通信できるように、以下のInterface VPC Endpointを作成します。

| Endpoint    | 用途                       |
| ----------- | ------------------------ |
| ssm         | Systems Manager API通信用   |
| ssmmessages | Session Managerのメッセージ通信用 |
| ec2messages | SSM AgentとAWS間のメッセージ通信用  |

VPC Endpoint用Security Groupでは、VPC CIDRからのHTTPS通信のみ許可します。

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

## Terraformファイル構成

```text
.
├─ main.tf
├─ variables.tf
├─ outputs.tf
├─ .gitignore
└─ README.md
```

## 変数

主な変数は `variables.tf` で管理します。

| 変数名                 | デフォルト値          | 説明                  |
| ------------------- | --------------- | ------------------- |
| aws_region          | ap-northeast-1  | AWSリージョン            |
| aws_profile         | yoshihiro-admin | AWS CLIプロファイル       |
| vpc_cidr            | 10.0.0.0/16     | VPC CIDR            |
| public_subnet_cidr  | 10.0.1.0/24     | Public Subnet CIDR  |
| private_subnet_cidr | 10.0.2.0/24     | Private Subnet CIDR |
| availability_zone   | ap-northeast-1a | Availability Zone   |
| instance_type       | t3.micro        | EC2インスタンスタイプ        |
| root_volume_size    | 30              | EBS root volumeサイズ  |

## 使い方

### 1. 初期化

```powershell
terraform init
```

### 2. フォーマット

```powershell
terraform fmt
```

### 3. 構文チェック

```powershell
terraform validate
```

### 4. 実行計画確認

```powershell
terraform plan
```

### 5. 作成

```powershell
terraform apply
```

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

## EC2停止

検証後、EC2を停止する場合は以下を実行します。

```powershell
terraform output -raw stop_instance_command
```

表示されたコマンドを実行します。

```powershell
aws ec2 stop-instances --instance-ids <instance-id> --region ap-northeast-1 --profile yoshihiro-admin
```

## 削除

検証環境を削除する場合は以下を実行します。

```powershell
terraform destroy
```

## 注意点

この構成ではEC2を停止しても、VPC EndpointやEBSなど一部リソースには課金が発生する可能性があります。
検証が終わった環境を完全に削除する場合は `terraform destroy` を実行します。

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
* GitHubによるTerraformコード管理
