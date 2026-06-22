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

## Bootstrap

このリポジトリでは、検証対象のAWSリソースとは別に、Terraform運用に必要な基盤を `bootstrap/` 配下で管理しています。

| Directory                | Description                                |
| ------------------------ | ------------------------------------------ |
| `bootstrap/backend/`     | Terraform Remote Backend用のS3 bucketを作成     |
| `bootstrap/github-oidc/` | GitHub ActionsからAWSへOIDC認証するためのIAM Roleを作成 |

`bootstrap/` 配下は、Terraformを実務に近い形で運用するための補助構成です。

---

## S3 Remote Backend

Terraform stateをローカルではなく、S3 Remote Backendで管理する構成にしています。

Remote Backend用のS3 bucketは `bootstrap/backend/` のTerraformで作成し、`terraform init -migrate-state` により既存のlocal stateをS3へ移行しています。

また、state lockにはS3 backendの `use_lockfile = true` を利用し、S3上に一時的なlock fileを作成する方式にしています。

これにより、Terraform stateをローカルPCに依存せず、実務に近いRemote Backend構成で管理できるようにしています。

---

## GitHub Actions / OIDC

このリポジトリでは、GitHub ActionsでTerraformのチェックを実行しています。

GitHub Actionsでは、AWSアクセスキーをGitHub Secretsに保存せず、GitHub OIDCを利用してAWS IAM Roleを一時的にAssumeします。

Workflowでは以下を実行します。

* `terraform fmt -check -recursive`
* `terraform init`
* `terraform validate`
* `terraform plan`

GitHub Actions用のIAM Roleは `bootstrap/github-oidc/` で作成しています。

この構成により、長期的なAWSアクセスキーを利用せずに、GitHub ActionsからS3 Remote Backendへアクセスし、Terraform planまで実行できます。

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
| GitHub ActionsからAWSへ認証する          | GitHub OIDC / IAM Role                       |
| Terraform stateを共有管理する            | S3 Remote Backend / S3 lockfile              |

---

## 実行コマンド

### 通常のTerraform操作

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

> `terraform apply` を実行するとAWSリソースが作成され、利用状況に応じて料金が発生します。事前に `terraform plan` の内容を確認してください。

1. NAT Gatewayは optional
2. enable_nat_gateway = true の時だけ Private EC2 から外部通信可能
3. enable_nat_gateway = false でも SSM / CloudWatch Logs は VPC Endpoint 経由で利用可能

### SSM接続

```powershell
aws ssm start-session `
  --target <instance-id> `
  --region ap-northeast-1 `
  --profile yoshihiro-admin
```

### CloudWatch Logs確認

```powershell
aws logs tail "/terraform-vpc-ec2-ssm/tmp/cwagent-test" `
  --since 10m `
  --region ap-northeast-1 `
  --profile yoshihiro-admin
```

---

## Directory Structure

```text
.
├─ .github/
│  └─ workflows/
│     └─ terraform.yml
│
├─ bootstrap/
│  ├─ backend/
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  └─ outputs.tf
│  │
│  └─ github-oidc/
│     ├─ main.tf
│     ├─ variables.tf
│     └─ outputs.tf
│
├─ docs/
│  ├─ architecture.md
│  ├─ interview-notes.md
│  └─ terraform-learning-log.md
│
├─ modules/
│  ├─ iam/
│  │  ├─ README.md
│  │  ├─ main.tf
│  │  ├─ variables.tf
│  │  └─ outputs.tf
│  │
│  └─ network/
│     ├─ README.md
│     ├─ main.tf
│     ├─ variables.tf
│     └─ outputs.tf
│
├─ backend.tf
├─ main.tf
├─ variables.tf
├─ outputs.tf
└─ README.md
```

---

## 関連ドキュメント

詳細な検証記録や学習ログは `docs/` 配下に整理しています。

* [Architecture](docs/architecture.md)
* [Interview Notes](docs/interview-notes.md)
* [Terraform Learning Log](docs/terraform-learning-log.md)
