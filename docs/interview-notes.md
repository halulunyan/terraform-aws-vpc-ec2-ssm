\# Interview Notes: Terraform AWS Private EC2 with SSM



\## 1. 30秒説明



Terraformを使って、AWS上にVPC、Public Subnet、Private Subnet、EC2、IAM Role、VPC Endpointを構築しました。



EC2はPrivate Subnetに配置し、Public IPやSSHを使わず、AWS Systems Manager Session Managerで接続する構成にしています。



SSM接続に必要なInterface VPC Endpointとして、`ssm`、`ssmmessages`、`ec2messages` を作成し、EC2のSecurity Groupはインバウンドなしにしています。



また、IMDSv2必須化、EBS暗号化、variables.tf / outputs.tf整理、READMEと構成資料の作成、GitHub管理まで行いました。



\## 2. 1分説明



今回の検証では、TerraformでAWSの基本的なネットワーク構成と、Private Subnet上のEC2へ安全に接続する構成を作成しました。



VPCは `10.0.0.0/16` で作成し、Public SubnetとPrivate Subnetを分けています。

EC2はPrivate Subnetに配置し、Public IPは付与していません。



通常のSSH接続ではなく、AWS Systems Manager Session Managerを使って接続します。

Private SubnetからSSMへ通信できるように、Interface型のVPC Endpointを3つ作成しています。



\* ssm

\* ssmmessages

\* ec2messages



EC2には `AmazonSSMManagedInstanceCore` を付与したIAM Roleをアタッチし、SSM管理対象としてOnlineになることを確認しました。



セキュリティ面では、EC2のSecurity Groupはインバウンドなし、IMDSv2必須、EBS root volume暗号化、gp3指定としています。



Terraformコードは、`main.tf`、`variables.tf`、`outputs.tf` に分け、環境ごとの値は `terraform.tfvars`、共有用サンプルは `terraform.tfvars.example` として整理しました。



\## 3. 構成のポイント



\### Private SubnetにEC2を配置



EC2にPublic IPを付けず、外部から直接アクセスできない構成にしました。



\### SSHを使わない



キーペアを作成せず、22番ポートも開放していません。

管理アクセスはSSM Session Managerに統一しています。



\### VPC Endpointを利用



Private Subnet上のEC2がSSMと通信できるように、以下のInterface VPC Endpointを作成しました。



\* com.amazonaws.ap-northeast-1.ssm

\* com.amazonaws.ap-northeast-1.ssmmessages

\* com.amazonaws.ap-northeast-1.ec2messages



\### IAM Roleを利用



EC2に直接アクセスキーを置かず、IAM Role / Instance ProfileでSSMに必要な権限を付与しています。



使用ポリシー:



\* AmazonSSMManagedInstanceCore



\### Terraformのリファクタリング



初期構成では値をmain.tfに直接書いていましたが、後から以下のように整理しました。



\* variables.tfで変数宣言

\* outputs.tfで接続コマンドやIDを出力

\* terraform.tfvars.exampleでサンプル値を共有

\* terraform.tfvarsはGit管理対象外

\* READMEとdocsで説明資料化



\## 4. 実際に確認したこと



\### Terraform検証



```powershell

terraform fmt

terraform validate

terraform plan

```



`terraform plan` で `No changes` になることを確認しました。



\### SSM管理対象確認



```powershell

aws ssm describe-instance-information `

&#x20; --region ap-northeast-1 `

&#x20; --profile yoshihiro-admin `

&#x20; --query "InstanceInformationList\[\*].\[InstanceId,PingStatus,PlatformName]" `

&#x20; --output table

```



EC2が `Online` になることを確認しました。



\### SSM接続



```powershell

aws ssm start-session --target <instance-id> --region ap-northeast-1 --profile yoshihiro-admin

```



Private IPのみのEC2にSSM Session Managerで接続できることを確認しました。



\### VPC Endpoint確認



```powershell

aws ec2 describe-vpc-endpoints `

&#x20; --region ap-northeast-1 `

&#x20; --profile yoshihiro-admin `

&#x20; --filters "Name=vpc-id,Values=<vpc-id>" `

&#x20; --query "VpcEndpoints\[\*].\[ServiceName,State,PrivateDnsEnabled]" `

&#x20; --output table

```



3つのVPC Endpointが `available` で、Private DNSが有効であることを確認しました。



\## 5. ハマったポイントと対応



\### AWS SSO認証切れ



Terraform plan時にSSOトークン切れでエラーになりました。



対応:



```powershell

aws sso login --profile yoshihiro-admin

```



\### TargetNotConnected



EC2作成直後にSSM接続しようとしたところ、`TargetNotConnected` が出ました。



対応:



\* EC2がrunningか確認

\* SSM管理対象にOnlineで出ているか確認

\* VPC Endpointがavailableか確認

\* 数分待って再実行



\### VPC Endpointのservice\_name間違い



`ssm` Endpointのservice\_nameを誤って `ssmmessages` にしてしまいそうになりました。



Terraform plan前にコードレビューして修正しました。



正しい設定:



```hcl

service\_name = "com.amazonaws.${var.aws\_region}.ssm"

```



\## 6. 聞かれた場合の回答例



\### Q. なぜPrivate SubnetにEC2を置いたのですか？



外部から直接アクセスできない構成にするためです。

Public IPを付与せず、SSHも開けず、管理アクセスはSSM Session Managerに寄せることで、インバウンドを閉じたセキュアな構成にしました。



\### Q. なぜVPC Endpointが必要なのですか？



EC2をPrivate Subnetに置くと、Internet Gateway経由でSSMの公開エンドポイントへ到達できません。

そのため、Private Subnet内からAWS Systems Managerへプライベートに通信できるよう、Interface VPC Endpointを作成しました。



\### Q. SSM接続に必要なEndpointは何ですか？



今回の構成では以下の3つを作成しました。



\* ssm

\* ssmmessages

\* ec2messages



\### Q. EC2にはどのIAM権限を付けましたか？



EC2用のIAM Roleを作成し、AWS管理ポリシー `AmazonSSMManagedInstanceCore` をアタッチしました。

そのRoleをInstance Profile経由でEC2に付与しています。



\### Q. Terraformで意識したことは何ですか？



必ず `terraform validate` と `terraform plan` で確認してからapplyすることです。

特にEC2の再作成やVPC Endpointの差分など、意図しないdestroy / replaceが出ていないかを確認しました。



また、後から読みやすくするために、`variables.tf`、`outputs.tf`、`terraform.tfvars.example`、README、docsを整理しました。



\## 7. まとめ



この検証では、TerraformでAWSの基本ネットワークとPrivate Subnet上のEC2接続構成を作成しました。



単にEC2を起動するだけではなく、Public IPなし、SSHなし、インバウンドなし、SSM Session Manager接続、VPC Endpoint利用、IAM Role利用、IMDSv2必須化、EBS暗号化まで含めて構成しています。



また、Terraformコードを変数化し、GitHubで管理し、READMEと構成資料も作成しました。



