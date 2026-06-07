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

- **ALB deletion protection**: `aws_lb.main.enable_deletion_protection = false` — intentionally disabled for easier teardown in this environment (in `infra/ecs.tf`)
- **CloudWatch log group retention**: log groups now retain logs for **365 days** (in `infra/iam.tf`)
- **RDS snapshot tag copying**: `aws_db_instance.url_shortener.copy_tags_to_snapshot = true` (in `infra/database.tf`)
- **S3 hardening for ALB logs** (in `infra/gateway_endpoint.tf`):
  - **versioning enabled**
  - **default encryption using SSE-S3** (`AES256`) because ALB access log delivery cannot write to KMS-encrypted destination buckets
  - **bucket lifecycle policy** (expires objects after 90 days)
  - **abort incomplete multipart uploads** after 7 days
  - **EventBridge notifications** enabled
  - **server access logging enabled** (ALB logs bucket logs to a separate access-logs bucket)
  - **targeted Checkov skips** for KMS encryption on AWS service log buckets where the service requires S3-managed encryption or ACLs
- **WAF logging enabled** (in `infra/gateway_endpoint.tf`):
  - adds an S3 bucket for WAF logs
  - adds a Kinesis Firehose delivery stream named with the required `aws-waf-logs-` prefix to deliver WAF logs to S3
  - Firehose is **encrypted with the app CMK**
- **CloudFront logging enabled** (in `infra/cloudfront.tf`):
  - CloudFront standard logs use an S3 log bucket with SSE-S3
  - the log bucket enables `BucketOwnerPreferred` ownership controls because CloudFront standard logging requires ACL access
  - public ACLs are still blocked by the bucket public access block
- **WAF managed rules**: added `AWSManagedRulesAnonymousIpList` to satisfy the Log4j AMR policy check
- **S3 cross-region replication**: explicitly skipped for the ALB logs bucket (single-region, rebuildable logs)

## AWS logging service constraints

Some AWS log delivery services do not support the same S3 settings we use for normal application data:

- **ALB access logs**: the destination bucket must allow the Elastic Load Balancing log delivery service and use S3-managed encryption (`AES256`), not SSE-KMS.
- **S3 server access logs**: the destination bucket also uses S3-managed encryption for log delivery compatibility.
- **CloudFront standard logs**: the destination bucket must have ACL support enabled, so the bucket uses `BucketOwnerPreferred` ownership controls.
- **WAF logs**: the Kinesis Firehose delivery stream name must start with `aws-waf-logs-`.

If these constraints are not met, `terraform apply` can fail with errors like:

- `Access Denied for bucket` when enabling ALB access logs.
- `The ARN isn't valid` for WAF logging if the Firehose stream name does not start with `aws-waf-logs-`.
- `The S3 bucket that you specified for CloudFront logs does not enable ACL access` when CloudFront standard logging targets an ACL-disabled bucket.

## Implications for `terraform destroy`

### ALB deletion protection can block destroy

`enable_deletion_protection` is currently set to `false`, so ALB deletion will not be blocked during destroy.

If you ever re-enable it, run the teardown workflow below first:

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

Note that `force_destroy = false` on the ALB logs bucket — you will need to empty it manually before `terraform destroy` can remove it.

### KMS key note

If your `aws_kms_key.app` is configured with a deletion window, destroying it may schedule deletion rather than deleting instantly (AWS behavior). If destroy ever fails around KMS, the fix is usually "don't destroy the CMK in ephemeral environments" or accept the scheduled deletion window.

## Terraform state bucket policy (SEC-3)

The remote backend bucket is not created by this stack, but `infra/state_bucket_policy.tf` can attach a **bucket policy** to the bucket configured through `TF_STATE_BUCKET` / `terraform_state_bucket_name`:

| Statement | Purpose |
|-----------|---------|
| **DenyInsecureTransport** | Rejects `s3:*` when `aws:SecureTransport` is false (TLS required). Always applied. |
| **AllowTerraformStateAccess** | Allows `ListBucket`, `GetObject`, `PutObject`, `DeleteObject`, etc. for roles listed in `terraform_state_access_role_arns`. |
| **DenyAccessNotFromAllowedRoles** | Optional explicit deny for everyone else when `terraform_state_enforce_allowlist = true`. |

Configure in gitignored `terraform.tfvars` (see `terraform.tfvars.example`):

```hcl
terraform_state_access_role_arns = [
  "arn:aws:iam::ACCOUNT_ID:role/your-github-actions-terraform-role",
]
terraform_state_enforce_allowlist = true
```

**Before enforcing the allowlist**, ensure every principal that runs `terraform plan/apply` (local laptop role, CI OIDC role) is in the list, or you will lock yourself out of state.

Applies to both state keys: `global/s3/url-shortener.tfstate` and `global/s3/url-shortener-ecr.tfstate` in the same bucket.

## Notes

- Deleting CloudWatch log groups **does not prevent recreation**. A later `terraform apply` will recreate them (but historical logs are gone once deleted).
