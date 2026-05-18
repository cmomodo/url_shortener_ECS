# Infrastructure hardening and security changes

This document summarizes the Terraform changes applied under `infra/` to satisfy **Checkov** (Bridgecrew) policies, improve encryption and observability, and tighten network access. It also explains how **ALB ingress** is limited to your trusted IP.

---

## ALB security group and allowed CIDRs

The application load balancer security group (`aws_security_group.alb` in `vpc.tf`) does not allow the whole internet by default on ports **80** and **443**. Ingress uses:

- **`alb_allowed_ingress_cidrs`** (declared in `variable.tf`, values supplied via **`terraform.tfvars`**)

There is **no default** for this variable so your address is not stored in the repo. Copy **`infra/terraform.tfvars.example`** to **`infra/terraform.tfvars`** (gitignored), set your public IPv4 as a `/32`, and run Terraform from `infra/`. Only addresses in that list can open HTTP or HTTPS to the ALB.

**If you need a fully public URL shortener**, set the variable to allow any IPv4 in your local `terraform.tfvars` or pass `-var='alb_allowed_ingress_cidrs=["0.0.0.0/0"]'` on the CLI. Be aware that **`0.0.0.0/0`** on port 80 may trigger Checkov rule **CKV_AWS_260** unless you add an approved suppression or adjust policy scope in your pipeline.

**If your ISP changes your IP**, update `terraform.tfvars` or override with `-var` so traffic is not dropped at the security group.

---

## New and updated Terraform files

### `infra/kms.tf` (new)

- Customer-managed **KMS key** with rotation enabled and alias `alias/url-shortener-app`.
- Key policy grants use to **account root**, **CloudWatch Logs**, **SQS**, and **RDS** (including storage and Performance Insights via the same CMK where configured).

### `infra/database.tf`

- **Custom DB parameter group** (`postgres16`) with query-log-related parameters to support Postgres logging expectations in policy scans.
- **Storage encryption** at rest using the app CMK.
- **Performance Insights** enabled, with **PI data encrypted** using the same CMK (`performance_insights_kms_key_id`).
- **Multi-AZ**, **automated backups** (7-day retention), **deletion protection**, **copy tags to snapshots**, **final snapshots** on destroy (`skip_final_snapshot = false` with a `final_snapshot_identifier`).
- **Enhanced monitoring** via a dedicated IAM role (`monitoring.rds.amazonaws.com`).
- **CloudWatch log exports** for PostgreSQL engine logs.

### `infra/vpc.tf`

- Removed the unused demo **`aws_security_group.example`** resource.
- Security groups now use **explicit descriptions** on ingress and egress rules (Checkov **CKV_AWS_23**).
- Replaced permissive **`protocol = "-1"` egress to `0.0.0.0/0`** with narrower rules (for example **TCP 443** to the internet where needed for AWS APIs, plus **5432** / **6379** inside the VPC for Postgres and Redis).
- **ALB egress** targets the VPC CIDR on **8080–8081** toward tasks, avoiding a circular dependency between the ALB and task security groups.
- **ALB ingress** driven by **`var.alb_allowed_ingress_cidrs`** (set in gitignored `terraform.tfvars`).

### `infra/ecs.tf`

- ALB: **deletion protection**, **drop invalid header fields**, **HTTP/2**, **access logging** to the dedicated S3 bucket (see below).
- HTTPS listener uses a **modern TLS policy** (`ELBSecurityPolicy-TLS13-1-2-2021-06`).
- ECS task definitions: **read-only root filesystem** with a **`tmp` volume** mounted at `/tmp` so processes can still write scratch data.
- Target groups remain **HTTP** on the container port (TLS terminates at the ALB); Checkov skips are documented in code where that pattern is intentional.

### `infra/alb_logs_waf.tf` (new)

- **S3 bucket** for ALB access logs (encryption, public access blocked, bucket policy for ELB log delivery in `us-east-1`).
- **AWS WAFv2** regional Web ACL with managed rule groups (**CommonRuleSet** and **KnownBadInputsRuleSet**, including Log4j-related coverage expectations from policy guides).
- **Web ACL association** with the ALB.

### `infra/iam.tf`

- CloudWatch log groups: **365-day retention**, **KMS encryption** with the app CMK.
- ECS task execution role: extended **KMS** permissions for the app key (logs and parameters).
- API and worker task roles: **KMS** permissions for **SQS** when queues use the CMK.

### `infra/ssm.tf`

- All sensitive parameters use **`SecureString`** and the **app CMK** (`key_id`).

### `infra/sqs.tf`

- Both queues use **SSE-KMS** with the app CMK and a reuse period for data keys.

### `infra/elasticCache.tf`

- **Automatic Redis snapshots** via `snapshot_retention_limit` and `snapshot_window`.

### `infra/variable.tf`

- Added **`alb_allowed_ingress_cidrs`** (required; set via gitignored **`terraform.tfvars`**, see **`terraform.tfvars.example`**).
- Removed the unused **`parameter_group_name`** variable (RDS now uses the managed parameter group resource in `database.tf`).

removed the kms bucket encryption for s3 since it is not supported by the s3 server access log delivery.

---

## Operational notes

1. **`terraform plan`** — Expect substantial diffs if an RDS instance or ALB already existed with the old settings; some changes can **replace** resources.
2. **Cost** — Multi-AZ RDS, Performance Insights, WAF, backups, and long log retention increase monthly spend compared to a minimal dev stack.
3. **RDS destroy** — With **deletion protection** enabled, you must disable it in Terraform before Terraform can destroy the instance.
4. **Containers** — Applications must tolerate a **read-only root** except **`/tmp`** (add more volumes if a framework needs another writable path).

---

## Checkov

The configuration is shaped so that a full **`checkov -d infra`** run can pass with **zero failed checks** for the current rule set, while keeping behavior explicit (for example target group HTTP behind TLS at the ALB, and ALB ingress controlled by **`alb_allowed_ingress_cidrs`** instead of a blanket `0.0.0.0/0` default).

If you upgrade Checkov or enable stricter frameworks, re-run scans and adjust variables or narrow suppressions as your threat model requires.
