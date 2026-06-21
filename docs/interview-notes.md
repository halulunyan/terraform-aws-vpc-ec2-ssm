# Interview Notes: Terraform AWS Private EC2 with SSM and CloudWatch Logs

## 1. 30秒説明

Terraformを使って、AWS上にVPC、Public Subnet、Private Subnet、EC2、IAM Role、VPC Endpointを構築しました。

EC2はPrivate Subnetに配置し、Public IPやSSHを使わず、AWS Systems Manager Session Managerで接続する構成にしています。

SSM接続に必要なInterface VPC Endpointとして、`ssm`、`ssmmessages`、`ec2messages` を作成し、CloudWatch Logs送信用に `logs` Endpointも追加しています。

EC2のSecurity Groupはインバウンドなしにし、IMDSv2必須化、EBS暗号化、CloudWatch Agentによるログ送信、NAT Gatewayなしでの閉域寄り構成まで検証しました。

また、Terraform module化、README / docs整備、GitHub Actionsによる自動チェック、GitHub公開まで行っています。

---

## 2. 1分説明

今回の検証では、TerraformでAWSの基本的なネットワーク構成と、Private Subnet上のEC2へ安全に接続する構成を作成しました。

VPCは `10.0.0.0/16` で作成し、Public SubnetとPrivate Subnetを分けています。

EC2はPrivate Subnetに配置し、Public IPは付与していません。

通常のSSH接続ではなく、AWS Systems Manager Session Managerを使って接続します。

Private SubnetからSSMへ通信できるように、Interface型のVPC Endpointを3つ作成しています。

* ssm
* ssmmessages
* ec2messages

また、CloudWatch AgentからCloudWatch Logsへログ送信するために、CloudWatch Logs用のVPC Endpointも作成しています。

* logs

EC2には `AmazonSSMManagedInstanceCore` と `CloudWatchAgentServerPolicy` を付与したIAM Roleをアタッチし、SSM接続とCloudWatch Logs送信ができることを確認しました。

セキュリティ面では、EC2のSecurity Groupはインバウンドなし、IMDSv2必須、EBS root volume暗号化、gp3指定としています。

Terraformコードは、root moduleとchild moduleに分割し、`network` moduleと `iam` moduleとして整理しました。

また、GitHub Actionsで `terraform fmt`、`terraform init`、`terraform validate` を自動チェックする構成にしています。

---

## 3. 構成のポイント

### Private SubnetにEC2を配置

EC2にPublic IPを付けず、外部から直接アクセスできない構成にしました。

### SSHを使わない

キーペアを作成せず、22番ポートも開放していません。

管理アクセスはSSM Session Managerに統一しています。

### VPC Endpointを利用

Private Subnet上のEC2がSSMおよびCloudWatch Logsと通信できるように、以下のInterface VPC Endpointを作成しました。

* com.amazonaws.ap-northeast-1.ssm
* com.amazonaws.ap-northeast-1.ssmmessages
* com.amazonaws.ap-northeast-1.ec2messages
* com.amazonaws.ap-northeast-1.logs

### IAM Roleを利用

EC2に直接アクセスキーを置かず、IAM Role / Instance Profileで必要な権限を付与しています。

使用ポリシー:

* AmazonSSMManagedInstanceCore
* CloudWatchAgentServerPolicy

### NAT Gatewayなしの構成

一時的にNAT Gatewayを作成し、Private Subnetから外部リポジトリへ到達できることを確認しました。

その後、Private Route Tableから `0.0.0.0/0 -> NAT Gateway` のルートを削除し、NAT Gateway本体とElastic IPも削除しました。

NAT Gateway削除後も、SSM接続とCloudWatch Logs送信はVPC Endpoint経由で継続できることを確認しました。

一方で、`curl https://aws.amazon.com` はtimeoutとなり、一般インターネット通信はできないことも確認しました。

### Terraformのリファクタリング

初期構成では値を `main.tf` に直接書いていましたが、後から以下のように整理しました。

* `variables.tf` で変数宣言
* `outputs.tf` で接続コマンドやIDを出力
* `terraform.tfvars.example` でサンプル値を共有
* `terraform.tfvars` はGit管理対象外
* `network` moduleと `iam` moduleに分割
* root READMEは全体概要、module READMEはmodule詳細、docsは検証記録として整理

---

## 4. 実際に確認したこと

### Terraform検証

```powershell
terraform fmt -recursive
terraform validate
terraform plan
```

`terraform plan` で `No changes` になることを確認しました。

### SSM管理対象確認

```powershell
aws ssm describe-instance-information `
  --region ap-northeast-1 `
  --profile yoshihiro-admin `
  --query "InstanceInformationList[*].[InstanceId,PingStatus,PlatformName]" `
  --output table
```

EC2が `Online` になることを確認しました。

### SSM接続

```powershell
aws ssm start-session --target <instance-id> --region ap-northeast-1 --profile yoshihiro-admin
```

Private IPのみのEC2にSSM Session Managerで接続できることを確認しました。

### VPC Endpoint確認

```powershell
aws ec2 describe-vpc-endpoints `
  --region ap-northeast-1 `
  --profile yoshihiro-admin `
  --filters "Name=vpc-id,Values=<vpc-id>" `
  --query "VpcEndpoints[*].[ServiceName,State,PrivateDnsEnabled]" `
  --output table
```

SSM用EndpointとCloudWatch Logs用Endpointが `available` で、Private DNSが有効であることを確認しました。

### CloudWatch Logs確認

```powershell
aws logs tail "/terraform-vpc-ec2-ssm/tmp/cwagent-test" `
  --since 10m `
  --region ap-northeast-1 `
  --profile yoshihiro-admin
```

CloudWatch AgentからCloudWatch Logsへログが送信されることを確認しました。

### NAT Gatewayなしの通信確認

```powershell
curl -I https://aws.amazon.com --max-time 10
```

NAT Gatewayへのdefault routeを削除した状態では、一般インターネット向け通信がtimeoutになることを確認しました。

その一方で、SSM接続とCloudWatch Logs送信はVPC Endpoint経由で継続できることを確認しました。

---

## 5. ハマったポイントと対応

### AWS SSO認証切れ

Terraform plan時にSSOトークン切れでエラーになりました。

対応:

```powershell
aws sso login --profile yoshihiro-admin
```

### TargetNotConnected

EC2作成直後にSSM接続しようとしたところ、`TargetNotConnected` が出ました。

対応:

* EC2がrunningか確認
* SSM管理対象にOnlineで出ているか確認
* VPC Endpointがavailableか確認
* IAM Role / Instance Profileが付与されているか確認
* 数分待って再実行

### VPC Endpointのservice_name確認

SSM接続には複数のEndpointが必要なため、`service_name` の指定を確認しました。

正しい設定例:

```hcl
service_name = "com.amazonaws.${var.aws_region}.ssm"
```

### NAT Gatewayなしでは外部通信できない

Private Subnetから外部リポジトリへ到達するには、NAT GatewayやProxyなどの外部出口が必要です。

一方で、SSMやCloudWatch LogsのようなAWSサービスについては、Interface VPC Endpointを作成すればNAT Gatewayなしでも通信できることを確認しました。

---

## 6. 聞かれた場合の回答例

### Q. なぜPrivate SubnetにEC2を置いたのですか？

外部から直接アクセスできない構成にするためです。

Public IPを付与せず、SSHも開けず、管理アクセスはSSM Session Managerに寄せることで、インバウンドを閉じたセキュアな構成にしました。

### Q. なぜVPC Endpointが必要なのですか？

EC2をPrivate Subnetに置くと、Internet Gateway経由でAWSサービスの公開エンドポイントへ到達できません。

そのため、Private Subnet内からAWS Systems ManagerやCloudWatch Logsへプライベートに通信できるよう、Interface VPC Endpointを作成しました。

### Q. SSM接続に必要なEndpointは何ですか？

今回の構成では以下の3つを作成しました。

* ssm
* ssmmessages
* ec2messages

### Q. CloudWatch Logs送信に必要なEndpointは何ですか？

CloudWatch Logsへログ送信するために、以下のEndpointを作成しました。

* logs

### Q. EC2にはどのIAM権限を付けましたか？

EC2用のIAM Roleを作成し、AWS管理ポリシー `AmazonSSMManagedInstanceCore` と `CloudWatchAgentServerPolicy` をアタッチしました。

そのRoleをInstance Profile経由でEC2に付与しています。

### Q. NAT Gatewayなしで何ができますか？

NAT Gatewayなしでは、一般インターネット向け通信はできません。

ただし、VPC Endpointを作成したAWSサービスにはPrivateLink経由で到達できます。

今回の構成では、NAT GatewayなしでもSSM接続とCloudWatch Logs送信が継続できることを確認しました。

### Q. Terraformで意識したことは何ですか？

必ず `terraform validate` と `terraform plan` で確認してからapplyすることです。

特にEC2の再作成やVPC Endpointの差分など、意図しないdestroy / replaceが出ていないかを確認しました。

また、後から読みやすくするために、`variables.tf`、`outputs.tf`、`terraform.tfvars.example`、README、docs、module READMEを整理しました。

---

## 7. まとめ

この検証では、TerraformでAWSの基本ネットワークとPrivate Subnet上のEC2接続構成を作成しました。

単にEC2を起動するだけではなく、Public IPなし、SSHなし、インバウンドなし、SSM Session Manager接続、VPC Endpoint利用、IAM Role利用、IMDSv2必須化、EBS暗号化、CloudWatch Logs送信まで含めて構成しています。

また、NAT Gatewayを削除した状態でも、SSM接続とCloudWatch Logs送信がVPC Endpoint経由で継続できることを確認しました。

Terraformコードはmodule化し、GitHub Actionsで自動チェックし、README / docs / module READMEを整備したうえでGitHubに公開しています。
