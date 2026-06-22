# terraform-aws-vpc-ec2-ssm

TerraformでAWS上に、Private Subnet配置のEC2と、SSM Session Manager / CloudWatch Logs用のVPC Endpointを構築する検証リポジトリです。

Public IPなし、SSHなし、Security Group InboundなしのEC2に対して、SSM Session Managerで管理接続し、CloudWatch AgentからCloudWatch Logsへログ送信できることを検証しています。

また、NAT Gatewayを削除した状態でも、SSM接続とCloudWatch Logs送信がVPC Endpoint経由で継続できることを確認しています。

---

## Architecture

```text
VPC
├─ Public Subnet
│  └─ Internet Gateway
│
├─ Private Subnet
│  └─ EC2 Instance
│      ├─ Public IPなし
│      ├─ SSHなし
│      ├─ Security Group Inboundなし
│      └─ SSM / CloudWatch Logs はVPC Endpoint経由
│
├─ Interface VPC Endpoints
│  ├─ ssm
│  ├─ ssmmessages
│  ├─ ec2messages
│  └─ logs
│
└─ NAT Gatewayなし
```

---

## 作成する主なリソース

* VPC
* Public Subnet
* Private Subnet
* Internet Gateway
* Route Table
* EC2 Instance
* Security Group
* IAM Role / Instance Profile
* Interface VPC Endpoint

  * ssm
  * ssmmessages
  * ec2messages
  * logs

---

## Modules

このリポジトリでは、Terraform構成をmodule単位に分割しています。

| Module                               | Description                                                    |
| ------------------------------------ | -------------------------------------------------------------- |
| [network](modules/network/README.md) | VPC、Subnet、Internet Gateway、Route Tableを作成                     |
| [iam](modules/iam/README.md)         | EC2からSSM / CloudWatch Logsを利用するためのIAM RoleとInstance Profileを作成 |

---

## 検証したこと

### SSM Session Manager接続

Private Subnet上のEC2に対して、以下の条件でSSM接続できることを確認しました。

* Public IPなし
* SSHなし
* 22番ポート開放なし
* Security Group Inboundなし
* 踏み台サーバなし

SSM接続は以下のVPC Endpoint経由で実現しています。

* ssm
* ssmmessages
* ec2messages

### CloudWatch Logs送信

CloudWatch AgentをEC2にインストールし、ログファイルをCloudWatch Logsへ送信できることを確認しました。

CloudWatch Logs送信は以下のVPC Endpoint経由で実現しています。

* logs

### NAT Gatewayなしでの閉域検証

NAT Gatewayへのdefault routeを削除し、さらにNAT Gateway本体とElastic IPも削除した状態で、以下を確認しました。

| 検証内容              | 結果           |
| ----------------- | ------------ |
| SSM接続             | 成功           |
| CloudWatch Logs送信 | 成功           |
| 一般インターネット通信       | 失敗 / timeout |

これにより、NAT GatewayとVPC Endpointの役割分担を確認しました。

---

## 役割分担

| 通信内容                              | 必要な仕組み                                       |
| --------------------------------- | -------------------------------------------- |
| Private EC2から一般インターネットへ出る         | NAT Gateway / Proxyなど                        |
| Private EC2からSSMへ接続する             | ssm / ssmmessages / ec2messages VPC Endpoint |
| Private EC2からCloudWatch Logsへ送信する | logs VPC Endpoint                            |

---

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

### S3 Remote Backend

Terraform stateをローカルではなく、S3 Remote Backendで管理する構成にしました。

Remote Backend用のS3 bucketをbootstrap用Terraformで作成し、`terraform init -migrate-state` により既存のlocal stateをS3へ移行しています。

また、state lockにはS3 backendの `use_lockfile = true` を利用し、S3上に一時的なlock fileを作成する方式にしています。

これにより、Terraform stateをローカルPCに依存せず、実務に近いRemote Backend構成で管理できるようにしています。

---
## 関連ドキュメント

詳細な検証記録や学習ログは `docs/` 配下に整理しています。

* [Architecture](docs/architecture.md)
* [Interview Notes](docs/interview-notes.md)
* [Terraform Learning Log](docs/terraform-learning-log.md)
