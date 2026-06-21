\# iam module



Private EC2からSSM Session ManagerとCloudWatch Logsを利用するためのIAM Role / Instance Profileを作成するTerraform moduleです。



EC2にはこのmoduleで作成したInstance Profileを付与します。



\---



\## 作成するリソース



\* IAM Role

\* IAM Instance Profile

\* IAM Policy Attachment



&#x20; \* `AmazonSSMManagedInstanceCore`

&#x20; \* `CloudWatchAgentServerPolicy`



\---



\## Purpose



このmoduleの目的は、Private Subnet上のEC2に以下の権限を付与することです。



| 用途                      | 利用するAWSサービス            |

| ----------------------- | ---------------------- |

| SSM Session Manager接続   | AWS Systems Manager    |

| CloudWatch Agentによるログ送信 | Amazon CloudWatch Logs |



\---



\## Attached Policies



| Policy                         | Purpose                                       |

| ------------------------------ | --------------------------------------------- |

| `AmazonSSMManagedInstanceCore` | EC2をSSM Managed Instanceとして利用するための権限          |

| `CloudWatchAgentServerPolicy`  | CloudWatch AgentからCloudWatch Logsへログ送信するための権限 |



\---



\## Inputs



| Name                    | Description               |

| ----------------------- | ------------------------- |

| `role\_name`             | EC2に付与するIAM Role名         |

| `instance\_profile\_name` | EC2に付与するInstance Profile名 |



\---



\## Outputs



| Name                    | Description           |

| ----------------------- | --------------------- |

| `role\_name`             | 作成したIAM Role名         |

| `instance\_profile\_name` | 作成したInstance Profile名 |



\---



\## Notes



このmoduleはIAM権限のみを作成します。



SSM接続に必要なVPC Endpointや、CloudWatch Logs用VPC Endpointはroot module側で作成します。



