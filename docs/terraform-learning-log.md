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

## S3 Remote Backend化

Terraform stateをローカル管理からS3 Remote Backend管理へ移行しました。

### 作成したもの

- Terraform state保存用S3 bucket
- S3 bucket versioning
- S3 server-side encryption
- S3 public access block

当初はDynamoDB tableによるstate lockも作成しましたが、TerraformのS3 backendで `dynamodb_table` がdeprecated warningとなったため、最終的には `use_lockfile = true` に変更しました。

### 確認したこと

- `terraform init -migrate-state` によりlocal stateをS3へ移行
- S3 bucket上に `terraform.tfstate` が作成されることを確認
- `terraform plan` で `No changes` を確認
- `use_lockfile = true` により、plan実行中に `terraform.tfstate.tflock` が一時的に作成されることを確認
- DynamoDB lock tableは不要になったため削除

### 学んだこと

Terraform stateは、Terraformが現在管理しているAWSリソースを記録する管理台帳です。

S3 Remote Backendを使うことで、stateをローカルPCではなくS3上で管理できます。

また、S3 lockfile方式では、Terraform実行中にS3上へlock fileが一時的に作成され、同じstateを複数のTerraformプロセスが同時に操作しないように制御できます。
