At the moment we are using Terraform to deploy the infrastructure for the url shortener.

## How to deploy

From the repo root:

```bash
cd infra
terraform init
terraform apply
```

Run the main stack only from the `modules` revision (or from a commit known to
have the same module layout as `modules`). The remote state records Terraform
resource addresses, so running an older flat configuration against newer
module-based state can produce a plan that destroys module resources and then
tries to recreate the same AWS names.

Always review a saved plan before applying:

```bash
cd infra
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
terraform plan -detailed-exitcode
```

The last command returns exit code `0` only when AWS and the configuration are
fully converged.

## Recovering an interrupted or mismatched apply

Errors such as `EntityAlreadyExists`, `BucketAlreadyExists`, or a VPC endpoint
DNS/route conflict normally mean the AWS resource exists but the selected
Terraform state does not track it. Do not delete a logs bucket or another
durable resource merely to make the next apply pass.

1. Stop competing Terraform runs and confirm the S3 state lock is gone.
2. Back up the current state with `terraform state pull`.
3. Compare the configuration revision, state resource addresses, and live AWS
   resources before changing state.
4. If one verified resource is missing from state, import it at the address
   used by the current configuration.
5. Run a fresh saved plan and apply only after confirming that it contains no
   unintended deletes or replacements.
6. Finish with `terraform plan -detailed-exitcode`; exit code `0` is the
   recovery success criterion.

For example, if creation of the S3 gateway endpoint fails because the private
route table already has the S3 prefix-list route:

```bash
aws ec2 describe-vpc-endpoints \
  --region us-east-1 \
  --filters Name=vpc-id,Values=<vpc-id> \
            Name=service-name,Values=com.amazonaws.us-east-1.s3

terraform import \
  'module.endpoints.aws_vpc_endpoint.s3' \
  <verified-vpc-endpoint-id>

terraform plan -detailed-exitcode
```

Verify the VPC ID, service name, route table, and expected `Name` tag before
importing. Import adopts the existing resource; it does not recreate or delete
it.

Restoring an older S3 state-object version is a broader recovery operation and
should be used only when the failed run changed many addresses. Preserve the
current state first, then verify the candidate state's lineage, serial,
resource count, module addresses, and S3 object checksum before using
`terraform state push`. Never use `terraform state rm` as a workaround for the
retained ALB logs bucket.

## Recent security/compliance changes (Checkov)

To pass the latest Checkov policies, the Terraform was updated to:

- **ALB deletion protection**: `aws_lb.main.enable_deletion_protection = false` — intentionally disabled for easier teardown in this environment (in `infra/ecs.tf`)
- **CloudWatch log group retention**: log groups now retain logs for **365 days** (in `infra/iam.tf`)
- **RDS snapshot tag copying**: `aws_db_instance.url_shortener.copy_tags_to_snapshot = true` (in `infra/database.tf`)
- **S3 hardening for ALB logs** (in `infra/modules/observability/main.tf`):
  - **versioning enabled**
  - **default encryption using SSE-S3** (`AES256`) because ALB access log delivery cannot write to KMS-encrypted destination buckets
  - **bucket lifecycle policy** (expires current objects after 90 days; it does not make immediate bucket deletion safe)
  - **Terraform destroy protection** (`prevent_destroy = true`) on the primary ALB logs bucket
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

### The ALB logs bucket is retained

The primary ALB logs bucket is a persistent audit record and has both
`force_destroy = false` and `prevent_destroy = true`. Terraform therefore
rejects a plan that would delete it while its resource block remains in the
selected configuration. The CI apply workflow also examines its saved plan and
stops before apply when the bucket has a `delete` action, including during an
incorrect Terraform address migration.

A full `terraform destroy` will fail at the planning stage while this bucket
remains in the main state. Do not work around the protection with
`terraform state rm`: that would leave an unmanaged bucket. To destroy the
application stack while retaining its logs, first move the persistent logging
resources to a separate Terraform root and state.

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

Applies to both state keys: `url-shortener-infra/terraform.tfstate` (main stack) and `url-shortener-ecr/terraform.tfstate` (bootstrap ECR stack) in the same bucket. These keys must match the `TF_STATE_KEY` and `TF_BOOTSTRAP_STATE_KEY` GitHub Actions variables used by the pipelines.

## Notes

- Deleting CloudWatch log groups **does not prevent recreation**. A later `terraform apply` will recreate them (but historical logs are gone once deleted).
