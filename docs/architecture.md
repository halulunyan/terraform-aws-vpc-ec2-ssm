## 2.1 Mermaid構成図

```mermaid
flowchart TB
    LocalPC["Local PC<br/>AWS CLI / SSM Start Session"]

    subgraph AWS["AWS Cloud"]
        SSM["AWS Systems Manager"]

        subgraph VPC["VPC: 10.0.0.0/16"]
            subgraph PublicSubnet["Public Subnet: 10.0.1.0/24"]
                IGW["Internet Gateway"]
                PublicRT["Public Route Table<br/>0.0.0.0/0 -> IGW"]
            end

            subgraph PrivateSubnet["Private Subnet: 10.0.2.0/24"]
                EC2["EC2 Amazon Linux 2023<br/>Private IP only<br/>No SSH<br/>No inbound<br/>IMDSv2 required<br/>EBS encrypted"]
                VPCE_SSM["VPC Endpoint<br/>ssm"]
                VPCE_SSMMessages["VPC Endpoint<br/>ssmmessages"]
                VPCE_EC2Messages["VPC Endpoint<br/>ec2messages"]
            end

            EndpointSG["Endpoint Security Group<br/>HTTPS 443 from VPC CIDR"]
            EC2SG["EC2 Security Group<br/>No inbound"]
            IAMRole["IAM Role<br/>AmazonSSMManagedInstanceCore"]
        end
    end

    LocalPC -->|"aws ssm start-session"| SSM
    SSM --> VPCE_SSM
    SSM --> VPCE_SSMMessages
    SSM --> VPCE_EC2Messages

    VPCE_SSM --> EC2
    VPCE_SSMMessages --> EC2
    VPCE_EC2Messages --> EC2

    EC2 --> EC2SG
    EC2 --> IAMRole
    VPCE_SSM --> EndpointSG
    VPCE_SSMMessages --> EndpointSG
    VPCE_EC2Messages --> EndpointSG

    PublicSubnet -. "future use: NAT Gateway / ALB" .-> PrivateSubnet