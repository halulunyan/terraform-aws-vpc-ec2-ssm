```md
## 学習ログ

Terraform module化、GitHub Actionsによる自動チェック、module化後のapply、SSM Session Manager接続確認までの詳細は以下に整理しています。

- [Terraform Learning Log](docs/terraform-learning-log.md)
```

## 今回の到達点

* Terraform module化完了

  * `network` module
  * `iam` module
* GitHub ActionsによるTerraform自動チェック完了

  * `terraform fmt -check -recursive`
  * `terraform init`
  * `terraform validate`
* Private Subnet上のEC2構築完了

  * Public IPなし
  * SSHなし
  * Security Group Inboundなし
* SSM Session ManagerによるPrivate EC2接続確認完了
* CloudWatch Agent導入完了
* CloudWatch Logsへのログ送信確認完了

  * `/tmp/cwagent-test.log`
  * `/var/log/dnf.log`
* CloudWatch Logs用VPC Endpoint追加完了

  * `logs`
* NAT Gatewayあり / なしの通信差分確認完了

  * NAT Gatewayあり：Private EC2から外部リポジトリへ到達可能
  * NAT Gatewayなし：一般インターネット通信はtimeout
  * NAT Gatewayなし：SSM接続とCloudWatch Logs送信はVPC Endpoint経由で継続可能
* NAT Gateway / Elastic IP削除完了
* `terraform plan` で `No changes` 確認完了
* README / docs 整備完了
* moduleごとのREADME追加完了

  * `modules/network/README.md`
  * `modules/iam/README.md`
* GitHubリポジトリ公開完了
* GitHub Actions成功確認完了

## 次の到達点

* Terraform stateのS3 Remote Backend化

  * state保存用S3 bucket作成
  * state lock用DynamoDB table作成
  * `backend.tf` 追加
  * `terraform init -migrate-state` 実行
  * remote backend移行後の `terraform plan` で `No changes` 確認
* Remote Backend化の内容をREADME / docsへ反映
* GitHubへcommit / push
