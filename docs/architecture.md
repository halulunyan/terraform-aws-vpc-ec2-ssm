\# Architecture: Private EC2 Access with AWS Systems Manager



\## 1. 構成概要



この構成は、Terraformを使用してAWS上にVPC、Public Subnet、Private Subnet、EC2、IAM Role、VPC Endpointを作成し、Private Subnet上のEC2へSSM Session Managerで接続する検証環境です。



EC2にはPublic IPを付与せず、SSH用のキーペアも使用しません。

Security Groupのインバウンドも開放せず、管理アクセスはAWS Systems Manager Session Managerに集約します。



\## 2. 全体構成図



```text

Local PC

&#x20; |

&#x20; | aws ssm start-session

&#x20; v

AWS Systems Manager

&#x20; |

&#x20; | Interface VPC Endpoint

&#x20; v

VPC: 10.0.0.0/16

├─ Public Subnet: 10.0.1.0/24

│  ├─ Internet Gateway

│  └─ Public Route Table

│

└─ Private Subnet: 10.0.2.0/24

&#x20;  ├─ EC2 Amazon Linux 2023

&#x20;  │  ├─ Public IPなし

&#x20;  │  ├─ SSHなし

&#x20;  │  ├─ Inboundなし

&#x20;  │  ├─ IAM Role: AmazonSSMManagedInstanceCore

&#x20;  │  ├─ IMDSv2 required

&#x20;  │  └─ EBS gp3 encrypted

&#x20;  │

&#x20;  └─ Interface VPC Endpoints

&#x20;     ├─ ssm

&#x20;     ├─ ssmmessages

&#x20;     └─ ec2messages

```



\## 3. Public Subnet版からPrivate Subnet版への変更点



初期構成では、EC2をPublic Subnetに配置していました。

その後、より実務に近い構成にするため、EC2をPrivate Subnetへ移動し、SSM接続に必要なVPC Endpointを追加しました。



| 項目                     | 変更前            | 変更後            |

| ---------------------- | -------------- | -------------- |

| EC2配置先                 | Public Subnet  | Private Subnet |

| Public IP              | あり             | なし             |

| SSH接続                  | 使用しない          | 使用しない          |

| Security Group Inbound | なし             | なし             |

| SSM接続経路                | AWS公開エンドポイント経由 | VPC Endpoint経由 |

| Internet Gateway到達性    | あり             | なし             |

| 実務寄り度                  | 基本検証           | よりセキュアな構成      |



\## 4. 各ブロックの役割



\### VPC



検証用のネットワーク全体を定義します。



\* CIDR: 10.0.0.0/16

\* DNS support: enabled

\* DNS hostnames: enabled



\### Public Subnet



Internet Gatewayへのルートを持つサブネットです。

現在EC2は配置していませんが、将来的にNAT GatewayやALBを配置する余地があります。



\* CIDR: 10.0.1.0/24

\* AZ: ap-northeast-1a

\* Auto-assign public IP: enabled



\### Private Subnet



EC2を配置するサブネットです。

Internet Gatewayへのデフォルトルートは持たせていません。



\* CIDR: 10.0.2.0/24

\* AZ: ap-northeast-1a

\* EC2配置先



\### Security Group



EC2用Security Groupではインバウンドを開放しません。

これにより、SSHやHTTPなどの直接接続を受け付けない構成にしています。



VPC Endpoint用Security Groupでは、VPC CIDRからのHTTPS通信のみ許可します。



\### IAM Role / Instance Profile



EC2がSSM管理対象として動作できるように、IAM Roleを付与します。



使用ポリシー:



\* AmazonSSMManagedInstanceCore



\### VPC Endpoint



Private Subnet上のEC2がSSMと通信するため、以下のInterface VPC Endpointを作成します。



\* com.amazonaws.ap-northeast-1.ssm

\* com.amazonaws.ap-northeast-1.ssmmessages

\* com.amazonaws.ap-northeast-1.ec2messages



\### EC2



Amazon Linux 2023をPrivate Subnetに配置します。



主な設定:



\* Public IPなし

\* Security Group Inboundなし

\* SSM接続

\* IMDSv2必須

\* gp3 EBS

\* EBS暗号化



\## 5. SSM接続確認



SSM管理対象としてOnlineになっているか確認します。



```powershell

aws ssm describe-instance-information `

&#x20; --region ap-northeast-1 `

&#x20; --profile yoshihiro-admin `

&#x20; --query "InstanceInformationList\[\*].\[InstanceId,PingStatus,PlatformName]" `

&#x20; --output table

```



期待値:



```text

InstanceId              PingStatus  PlatformName

i-xxxxxxxxxxxxxxxxx     Online      Amazon Linux

```



SSM接続:



```powershell

aws ssm start-session --target <instance-id> --region ap-northeast-1 --profile yoshihiro-admin

```



\## 6. VPC Endpoint確認



```powershell

aws ec2 describe-vpc-endpoints `

&#x20; --region ap-northeast-1 `

&#x20; --profile yoshihiro-admin `

&#x20; --filters "Name=vpc-id,Values=<vpc-id>" `

&#x20; --query "VpcEndpoints\[\*].\[ServiceName,State,PrivateDnsEnabled]" `

&#x20; --output table

```



期待値:



```text

com.amazonaws.ap-northeast-1.ssm           available  True

com.amazonaws.ap-northeast-1.ssmmessages   available  True

com.amazonaws.ap-northeast-1.ec2messages   available  True

```



\## 7. ハマりポイント



\### AWS SSO認証切れ



Terraform plan実行時に以下のエラーが発生することがあります。



```text

No valid credential sources found

InvalidGrantException

failed to refresh cached credentials

```



対応:



```powershell

aws sso login --profile yoshihiro-admin

```



\### SSM接続直後のTargetNotConnected



EC2作成直後は、SSM Agentが管理対象として登録されるまで数分かかることがあります。



対応:



\* EC2がrunningか確認

\* SSM管理対象にOnlineで出ているか確認

\* VPC Endpointがavailableか確認



\### Outputだけの変更



outputs.tfを変更した場合、AWSリソースは変更されず、Terraform state上のoutputsだけが変わることがあります。



この場合は以下のように表示されます。



```text

Resources: 0 added, 0 changed, 0 destroyed.

Changes to Outputs:

```



\## 8. 学習ポイント



この構成で学んだことは以下です。



\* TerraformによるAWSリソース管理

\* Public SubnetとPrivate Subnetの違い

\* EC2をPrivate Subnetに配置する構成

\* Public IPなしでEC2へ接続する方法

\* SSM Session Managerの利用

\* Interface VPC Endpointの役割

\* IAM Role / Instance Profileの役割

\* Security GroupでInboundを開けない設計

\* IMDSv2必須化

\* EBS暗号化

\* variables.tfによる変数化

\* outputs.tfによる操作コマンド出力

\* GitHubでのTerraformコード管理



