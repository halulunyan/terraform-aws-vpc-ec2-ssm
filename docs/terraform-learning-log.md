\# Terraform Learning Log



\## 目的



このドキュメントは、Terraformを用いたAWSインフラ構築学習の記録である。

単にTerraformコードを書くことではなく、以下を理解することを目的とした。



\* Terraformの基本操作

\* AWSリソース作成と削除

\* 変数化

\* outputsの役割

\* module化

\* GitHubによるコード管理

\* planによる差分確認

\* SSM Session Managerを利用したPrivate EC2接続



\## 作成したAWS構成



Terraformで以下の構成を作成した。



\* VPC

\* Public Subnet

\* Private Subnet

\* Internet Gateway

\* Public Route Table

\* Private Route Table

\* Security Group

\* VPC Endpoint



&#x20; \* ssm

&#x20; \* ssmmessages

&#x20; \* ec2messages

\* IAM Role

\* IAM Instance Profile

\* EC2



&#x20; \* Amazon Linux 2023

&#x20; \* Private Subnet配置

&#x20; \* Public IPなし

&#x20; \* SSHなし

&#x20; \* Security Group inboundなし

&#x20; \* IMDSv2必須

&#x20; \* EBS暗号化

\* SSM Session Manager接続



\## Terraform基本操作



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

&#x20; Terraform作業ディレクトリを初期化する



terraform fmt

&#x20; Terraformコードのフォーマットを整える



terraform validate

&#x20; Terraform構文や参照関係が正しいか確認する



terraform plan

&#x20; 実際に何が作成・変更・削除されるか確認する



terraform apply

&#x20; plan内容に従ってAWSリソースを作成・変更する



terraform destroy

&#x20; Terraform管理下のAWSリソースを削除する



terraform state list

&#x20; Terraform state上で管理されているリソース一覧を確認する

```



\## variables.tf / main.tf / outputs.tf の理解



Terraform moduleは、プログラムの関数のように考えると理解しやすい。



```text

variables.tf = 引数

main.tf      = 処理本体

outputs.tf   = 戻り値

```



\### variables.tf



`variables.tf` は、外部から受け取る値を定義する。



例：



```hcl

variable "vpc\_cidr" {

&#x20; description = "CIDR block for the VPC"

&#x20; type        = string

}

```



これは、moduleが `vpc\_cidr` という値を外から受け取れるようにする定義である。



\### main.tf



`main.tf` は、実際にAWSリソースを作成する本体である。



例：



```hcl

resource "aws\_vpc" "main" {

&#x20; cidr\_block = var.vpc\_cidr

}

```



ここでは、`variables.tf` で定義された `var.vpc\_cidr` を使ってVPCを作成している。



\### outputs.tf



`outputs.tf` は、作成したリソースの値を外部へ公開する。



例：



```hcl

output "vpc\_id" {

&#x20; value = aws\_vpc.main.id

}

```



module内で作成したVPC IDを外部へ返すことで、root module側から以下のように参照できる。



```hcl

module.network.vpc\_id

```



\## module化の理解



最初はrootの `main.tf` にすべてのAWSリソースを直接書いていた。



その後、VPC / Subnet / IGW / Route Table を `modules/network` に切り出した。



\### module化前



```text

root main.tf

&#x20; ├─ VPC

&#x20; ├─ Public Subnet

&#x20; ├─ Private Subnet

&#x20; ├─ Internet Gateway

&#x20; ├─ Route Table

&#x20; ├─ Security Group

&#x20; ├─ VPC Endpoint

&#x20; ├─ IAM

&#x20; └─ EC2

```



\### module化後



```text

root main.tf

&#x20; ├─ provider

&#x20; ├─ module "network"

&#x20; ├─ Security Group

&#x20; ├─ VPC Endpoint

&#x20; ├─ IAM

&#x20; └─ EC2



modules/network/main.tf

&#x20; ├─ VPC

&#x20; ├─ Public Subnet

&#x20; ├─ Private Subnet

&#x20; ├─ Internet Gateway

&#x20; ├─ Public Route Table

&#x20; └─ Private Route Table

```



root側では以下のようにmoduleを呼び出す。



```hcl

module "network" {

&#x20; source = "./modules/network"



&#x20; vpc\_cidr            = var.vpc\_cidr

&#x20; public\_subnet\_cidr  = var.public\_subnet\_cidr

&#x20; private\_subnet\_cidr = var.private\_subnet\_cidr

&#x20; availability\_zone   = var.availability\_zone

}

```



module内で作成したVPCやSubnetは、`modules/network/outputs.tf` で外部公開する。



```hcl

output "vpc\_id" {

&#x20; value = aws\_vpc.main.id

}



output "private\_subnet\_id" {

&#x20; value = aws\_subnet.private\_1a.id

}

```



root側では以下のように使う。



```hcl

vpc\_id    = module.network.vpc\_id

subnet\_id = module.network.private\_subnet\_id

```



\## module化で理解した重要ポイント



\### var.xxx



`var.xxx` は、変数として受け取った入力値を参照する。



例：



```hcl

cidr\_block = var.vpc\_cidr

```



これは、外から渡されたVPC CIDRを使うという意味である。



\### module.network.xxx



`module.network.xxx` は、moduleから返された出力値を参照する。



例：



```hcl

vpc\_id = module.network.vpc\_id

```



これは、network moduleで作成したVPC IDをroot側で使うという意味である。



\## 今回のmodule化で変更したこと



\### 変更前



rootの `main.tf` に以下のリソースが直接定義されていた。



```text

aws\_vpc.main

aws\_subnet.public\_1a

aws\_subnet.private\_1a

aws\_internet\_gateway.main

aws\_route\_table.public

aws\_route.public\_default

aws\_route\_table\_association.public\_1a

aws\_route\_table.private

aws\_route\_table\_association.private\_1a

```



\### 変更後



これらを `modules/network/main.tf` に移動した。



root側の参照も変更した。



```hcl

vpc\_id = aws\_vpc.main.id

```



から、



```hcl

vpc\_id = module.network.vpc\_id

```



へ変更。



```hcl

subnet\_id = aws\_subnet.private\_1a.id

```



から、



```hcl

subnet\_id = module.network.private\_subnet\_id

```



へ変更。



\## planで確認したこと



module化後に `terraform plan` を実行し、以下のように表示されることを確認した。



```text

module.network.aws\_vpc.main

module.network.aws\_subnet.public\_1a

module.network.aws\_subnet.private\_1a

module.network.aws\_internet\_gateway.main

module.network.aws\_route\_table.public

module.network.aws\_route\_table.private

```



これにより、VPC / Subnet / IGW / Route Table がroot直書きではなく、`modules/network` から作成される構成になったことを確認した。



\## Git管理



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



\## 学んだこと



今回の学習で、Terraform moduleの基本構造を理解した。



特に重要な理解は以下。



```text

variables.tf = 引数

main.tf      = 処理本体

outputs.tf   = 戻り値

```



また、`outputs.tf` は単なる実行結果の表示ファイルではなく、moduleでは外部公開インターフェースとして機能することを理解した。



\## 次にやること



次はIAM module化を行う。



対象は以下。



```text

aws\_iam\_role.ec2\_ssm\_role

aws\_iam\_role\_policy\_attachment.ec2\_ssm\_managed\_instance\_core

aws\_iam\_instance\_profile.ec2\_ssm\_profile

```



IAM module化後、root側のEC2では以下のように参照する想定。



```hcl

iam\_instance\_profile = module.iam.instance\_profile\_name

```



