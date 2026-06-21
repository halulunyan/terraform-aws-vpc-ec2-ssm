\# network module



AWS VPCネットワーク基盤を作成するTerraform moduleです。



このmoduleでは、Public Subnet / Private Subnetを持つVPCを作成し、Public SubnetにはInternet Gateway経由のdefault routeを設定します。



Private SubnetにはEC2などの内部向けリソースを配置する想定です。

現在の構成では、Private Subnetから一般インターネットへ出るNAT Gatewayは作成していません。



\---



\## 作成するリソース



\* VPC

\* Public Subnet

\* Private Subnet

\* Internet Gateway

\* Public Route Table

\* Private Route Table

\* Public Route Table Association

\* Private Route Table Association



\---



\## Network Design



```text

VPC

├─ Public Subnet

│  ├─ Internet Gateway

│  └─ Public Route Table

│      └─ 0.0.0.0/0 -> Internet Gateway

│

└─ Private Subnet

&#x20;  └─ Private Route Table

&#x20;     └─ default routeなし

```



\---



\## Inputs



| Name                  | Description                  |

| --------------------- | ---------------------------- |

| `vpc\_cidr`            | VPCのCIDR block               |

| `public\_subnet\_cidr`  | Public SubnetのCIDR block     |

| `private\_subnet\_cidr` | Private SubnetのCIDR block    |

| `availability\_zone`   | Subnetを作成するAvailability Zone |



\---



\## Outputs



| Name                     | Description            |

| ------------------------ | ---------------------- |

| `vpc\_id`                 | 作成したVPC ID             |

| `vpc\_cidr\_block`         | 作成したVPCのCIDR block     |

| `public\_subnet\_id`       | 作成したPublic Subnet ID   |

| `private\_subnet\_id`      | 作成したPrivate Subnet ID  |

| `public\_route\_table\_id`  | Public Route Table ID  |

| `private\_route\_table\_id` | Private Route Table ID |



\---



\## Notes



Private SubnetにはNAT Gatewayへのdefault routeを設定していません。



そのため、Private Subnet上のEC2は一般インターネットへ直接出られません。

SSM Session ManagerやCloudWatch LogsなどのAWSサービス利用は、root module側で作成するInterface VPC Endpoint経由で行います。



