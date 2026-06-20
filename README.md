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

# Terraform Learning Log

## 目的

このドキュメントは、Terraformを用いたAWSインフラ構築学習の記録である。
単にTerraformコードを書くことではなく、以下を理解することを目的とした。

* Terraformの基本操作
* AWSリソース作成と削除
* 変数化
* outputsの役割
* module化
* GitHubによるコード管理
* planによる差分確認
* SSM Session Managerを利用したPrivate EC2接続

## 作成したAWS構成

Terraformで以下の構成を作成した。

* VPC
* Public Subnet
* Private Subnet
* Internet Gateway
* Public Route Table
* Private Route Table
* Security Group
* VPC Endpoint

  * ssm
  * ssmmessages
  * ec2messages
* IAM Role
* IAM Instance Profile
* EC2

  * Amazon Linux 2023
  * Private Subnet配置
  * Public IPなし
  * SSHなし
  * Security Group inboundなし
  * IMDSv2必須
  * EBS暗号化
* SSM Session Manager接続

## Terraform基本操作

使用した主なコマンドは以下。

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
terraform state list
```

それぞれの役割は以下。

```text
terraform init
  Terraform作業ディレクトリを初期化する

terraform fmt
  Terraformコードのフォーマットを整える

terraform validate
  Terraform構文や参照関係が正しいか確認する

terraform plan
  実際に何が作成・変更・削除されるか確認する

terraform apply
  plan内容に従ってAWSリソースを作成・変更する

terraform destroy
  Terraform管理下のAWSリソースを削除する

terraform state list
  Terraform state上で管理されているリソース一覧を確認する
```

## variables.tf / main.tf / outputs.tf の理解

Terraform moduleは、プログラムの関数のように考えると理解しやすい。

```text
variables.tf = 引数
main.tf      = 処理本体
outputs.tf   = 戻り値
```

### variables.tf

`variables.tf` は、外部から受け取る値を定義する。

例：

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}
```

これは、moduleが `vpc_cidr` という値を外から受け取れるようにする定義である。

### main.tf

`main.tf` は、実際にAWSリソースを作成する本体である。

例：

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}
```

ここでは、`variables.tf` で定義された `var.vpc_cidr` を使ってVPCを作成している。

### outputs.tf

`outputs.tf` は、作成したリソースの値を外部へ公開する。

例：

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

module内で作成したVPC IDを外部へ返すことで、root module側から以下のように参照できる。

```hcl
module.network.vpc_id
```

## module化の理解

最初はrootの `main.tf` にすべてのAWSリソースを直接書いていた。

その後、VPC / Subnet / IGW / Route Table を `modules/network` に切り出した。

### module化前

```text
root main.tf
  ├─ VPC
  ├─ Public Subnet
  ├─ Private Subnet
  ├─ Internet Gateway
  ├─ Route Table
  ├─ Security Group
  ├─ VPC Endpoint
  ├─ IAM
  └─ EC2
```

### module化後

```text
root main.tf
  ├─ provider
  ├─ module "network"
  ├─ Security Group
  ├─ VPC Endpoint
  ├─ IAM
  └─ EC2

modules/network/main.tf
  ├─ VPC
  ├─ Public Subnet
  ├─ Private Subnet
  ├─ Internet Gateway
  ├─ Public Route Table
  └─ Private Route Table
```

root側では以下のようにmoduleを呼び出す。

```hcl
module "network" {
  source = "./modules/network"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}
```

module内で作成したVPCやSubnetは、`modules/network/outputs.tf` で外部公開する。

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_id" {
  value = aws_subnet.private_1a.id
}
```

root側では以下のように使う。

```hcl
vpc_id    = module.network.vpc_id
subnet_id = module.network.private_subnet_id
```

## module化で理解した重要ポイント

### var.xxx

`var.xxx` は、変数として受け取った入力値を参照する。

例：

```hcl
cidr_block = var.vpc_cidr
```

これは、外から渡されたVPC CIDRを使うという意味である。

### module.network.xxx

`module.network.xxx` は、moduleから返された出力値を参照する。

例：

```hcl
vpc_id = module.network.vpc_id
```

これは、network moduleで作成したVPC IDをroot側で使うという意味である。

## 今回のmodule化で変更したこと

### 変更前

rootの `main.tf` に以下のリソースが直接定義されていた。

```text
aws_vpc.main
aws_subnet.public_1a
aws_subnet.private_1a
aws_internet_gateway.main
aws_route_table.public
aws_route.public_default
aws_route_table_association.public_1a
aws_route_table.private
aws_route_table_association.private_1a
```

### 変更後

これらを `modules/network/main.tf` に移動した。

root側の参照も変更した。

```hcl
vpc_id = aws_vpc.main.id
```

から、

```hcl
vpc_id = module.network.vpc_id
```

へ変更。

```hcl
subnet_id = aws_subnet.private_1a.id
```

から、

```hcl
subnet_id = module.network.private_subnet_id
```

へ変更。

## planで確認したこと

module化後に `terraform plan` を実行し、以下のように表示されることを確認した。

```text
module.network.aws_vpc.main
module.network.aws_subnet.public_1a
module.network.aws_subnet.private_1a
module.network.aws_internet_gateway.main
module.network.aws_route_table.public
module.network.aws_route_table.private
```

これにより、VPC / Subnet / IGW / Route Table がroot直書きではなく、`modules/network` から作成される構成になったことを確認した。

## Git管理

TerraformコードはGitHubで管理している。

今回のmodule化は以下のコミットで反映済み。

```text
Refactor network resources into module
```

確認コマンド：

```powershell
git log --oneline -5
```

実行結果：

```text
73ef0ac Refactor network resources into module
```

## 学んだこと

今回の学習で、Terraform moduleの基本構造を理解した。

特に重要な理解は以下。

```text
variables.tf = 引数
main.tf      = 処理本体
outputs.tf   = 戻り値
```

また、`outputs.tf` は単なる実行結果の表示ファイルではなく、moduleでは外部公開インターフェースとして機能することを理解した。

```

## 学習ログ

Terraform module化、GitHub Actionsによる自動チェック、module化後のapply、SSM Session Manager接続確認までの詳細は以下に整理しています。

- [Terraform Learning Log](docs/terraform-learning-log.md)