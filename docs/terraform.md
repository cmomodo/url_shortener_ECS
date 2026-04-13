At the moment we are using Terraform to deploy the infrastructure for the url shortener.

## How to deploy

From the repo root:

```bash
cd infra
terraform init
terraform apply
```

## Recent security/compliance changes (Checkov)

To pass the latest Checkov policies, the Terraform was updated to:

- **ALB deletion protection**: `aws_lb.main.enable_deletion_protection = true` (in `infra/ecs.tf`)
- **CloudWatch log group retention**: log groups now retain logs for **365 days** (in `infra/iam.tf`)
- **RDS snapshot tag copying**: `aws_db_instance.url_shortener.copy_tags_to_snapshot = true` (in `infra/database.tf`)
- **S3 hardening for ALB logs** (in `infra/gateway_endpoint.tf`):
  - **versioning enabled**
  - **default encryption using KMS** (`aws:kms` with `aws_kms_key.app`)
  - **bucket lifecycle policy** (expires objects after 90 days)
  - **abort incomplete multipart uploads** after 7 days
  - **EventBridge notifications** enabled
  - **server access logging enabled** (ALB logs bucket logs to a separate access-logs bucket)
- **WAF logging enabled** (in `infra/gateway_endpoint.tf`):
  - adds an S3 bucket for WAF logs
  - adds a Kinesis Firehose delivery stream to deliver WAF logs to S3
  - Firehose is **encrypted with the app CMK**
- **WAF managed rules**: added `AWSManagedRulesAnonymousIpList` to satisfy the Log4j AMR policy check
- **S3 cross-region replication**: explicitly skipped for the ALB logs bucket (single-region, rebuildable logs)

## Implications for `terraform destroy`

### ALB deletion protection can block destroy

If `enable_deletion_protection = true`, AWS will reject deleting the ALB. That means `terraform destroy` will fail until you disable it first.

**Teardown workflow:**

```bash
cd infra

# 1) temporarily set enable_deletion_protection = false in infra/ecs.tf
terraform apply

# 2) now destroy
terraform destroy
```

After you recreate with `terraform apply`, you can set it back to `true`.

### More resources exist now (so destroy removes more things)

Because of Checkov-related changes, `terraform destroy` will also delete:
- **Extra S3 buckets**: access-logs bucket and WAF logs bucket
- **Kinesis Firehose + IAM role/policy** for WAF logging

Most of these are safe to destroy automatically because the buckets are configured with **`force_destroy = true`** (Terraform will delete objects and then the bucket). If you remove `force_destroy`, you’ll need to empty buckets before destroy.

### KMS key note

If your `aws_kms_key.app` is configured with a deletion window, destroying it may schedule deletion rather than deleting instantly (AWS behavior). If destroy ever fails around KMS, the fix is usually “don’t destroy the CMK in ephemeral environments” or accept the scheduled deletion window.

## Notes

- Deleting CloudWatch log groups **does not prevent recreation**. A later `terraform apply` will recreate them (but historical logs are gone once deleted).
