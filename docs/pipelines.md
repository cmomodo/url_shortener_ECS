## CI/CD Overview

The project uses **GitHub Actions** for all automation. There are three independent delivery paths:

| Pipeline | Workflow file | Tracked branch | Mutates AWS? |
| -------- | ------------- | -------------- | ------------ |
| Bootstrap (ECR) | `.github/workflows/bootstrap.yml` | `main` | Apply on push/manual |
| Main infra (Terraform) | `.github/workflows/ci.yml` | `main` | Apply on push/manual |
| Container deploy | `.github/workflows/docker.yml` + `.github/workflows/deploy.yml` | `main` | Yes — builds images and triggers CodeDeploy |

---

## CI/CD features

### Concurrency

Workflows use a `concurrency` group with `cancel-in-progress: true` so only one run per branch and action type is active at a time.

| Workflow | Concurrency group |
| -------- | ----------------- |
| Bootstrap | `bootstrap-<workflow>-<ref>-<plan\|apply>` |
| Main infra (`ci.yml`) | `ci-<workflow>-<ref>-<plan\|apply>` |

### OIDC

All GitHub Actions workflows authenticate to AWS with **OpenID Connect** — no long-lived access keys in GitHub.

1. GitHub Actions requests a short-lived OIDC token (`permissions: id-token: write`).
2. `aws-actions/configure-aws-credentials` exchanges that token for temporary AWS credentials via `sts:AssumeRoleWithWebIdentity`.
3. The runner assumes `AWS_TERRAFORM_ROLE_ARN` (secret), typically `url-shortener-github-terraform`.

Setup (once per account): run `scripts/setup_oidc.sh` then store the role ARN as the `AWS_TERRAFORM_ROLE_ARN` secret.

### Least privilege

| Role | Used by | Scope |
| ---- | ------- | ----- |
| `url-shortener-github-terraform` | GitHub Actions (all workflows) | Trust limited to the GitHub repo via OIDC |
| `url-shortener-codedeploy` | CodeDeploy (API blue/green) | `AWSCodeDeployRoleForECS` managed policy |
| `url-shortener-deployer` | Deploy workflow (register task def + trigger CodeDeploy) | `ecs:RegisterTaskDefinition`, `iam:PassRole` on task roles, scoped `codedeploy:CreateDeployment` |

Roles are defined in `infra/iam.tf`. The deployer policy (`url-shortener-deployer`) is created by Terraform — attach it to the GitHub OIDC role or any operator role that runs deployments.

### Artifacts

**GitHub Actions (Terraform)**

| Artifact | When uploaded | Retention |
| -------- | ------------- | --------- |
| `tfplan` + `tfplan.txt` | Every plan run | 14 days |

Apply always runs against the saved `tfplan` from the same workflow run.

---

## Bootstrap pipeline

Workflow: `.github/workflows/bootstrap.yml`

Provisions ECR repositories (`url-shortener/api`, `url-shortener/dashboard`, `url-shortener/worker`). Run **before** the main infra pipeline — the main stack reads those repos as data sources.

| Trigger | Condition | What happens |
| ------- | --------- | ------------ |
| Push to `main` | Only `infra-ecr/**`, `modules/ecr/**`, `.github/workflows/bootstrap.yml` | plan → apply → idempotency check |
| Pull request → `main` | Same path filter | plan only |
| Manual (`workflow_dispatch`) | Always | choose `plan` or `apply` |

State key: `TF_BOOTSTRAP_STATE_KEY` (expected `url-shortener-ecr/terraform.tfstate`).

---

## Main infra pipeline

Workflow: `.github/workflows/ci.yml`

Deploys the main AWS stack (`infra/`) with Terraform — VPC, ECS, RDS, ALB, CodeDeploy, IAM, etc.

| Trigger | Condition | What happens |
| ------- | --------- | ------------ |
| Push to `main` | Any file change | plan → apply → idempotency check |
| Pull request → `main` | Any change | plan only |
| Manual (`workflow_dispatch`) | Always | choose `plan` or `apply` |

State key: `TF_STATE_KEY` (expected `url-shortener-infra/terraform.tfstate`).

### Steps

1. Checkout
2. Setup Terraform v1.14.7
3. `terraform fmt -check`
4. Configure AWS credentials (OIDC)
5. `terraform init` with S3 remote state (native S3 lockfile, no DynamoDB required)
6. `terraform validate`
7. `terraform plan` — saves `tfplan` + `tfplan.txt` as artifacts
8. `terraform apply` (push or manual `apply` only)
9. Idempotency check — `terraform plan -detailed-exitcode`

---

## Container deploy pipeline

Two workflows work together to build images and deploy the API via CodeDeploy blue/green.

### Step 1 — Build and push (`docker.yml`)

Triggered when the CI (Terraform) workflow completes successfully on `main`.

Builds all three service images for **`linux/arm64`** (matching ARM64 Fargate tasks) using QEMU cross-compilation on the GitHub-hosted x86_64 runner, then pushes to ECR.

| Service | Build context | ECR repo |
| ------- | ------------- | -------- |
| api | `./app` | `url-shortener/api` |
| worker | `./services/worker` | `url-shortener/worker` |
| dashboard | `./services/dashboard` | `url-shortener/dashboard` |

Image tag format: `<sha7>-<YYYYMMDDTHHMMSSz>` (e.g. `a1b2c3d-20260612T115500Z`). A `:latest` tag is also pushed.

### Step 2 — Deploy API (`deploy.yml`)

Triggered when `docker.yml` completes successfully. Can also be run manually with a specific image tag via `workflow_dispatch`.

| Step | What happens |
| ---- | ------------ |
| Resolve image tag | Uses the tag from the build job, or the manually supplied `image_tag` input |
| Render task definition | Runs `ci/docker/render_taskdef.py` with all required env vars to substitute `${...}` placeholders in `ci/taskdef/api-taskdef.json` |
| Register task definition | `aws ecs register-task-definition` → returns the new task def ARN |
| Render appspec | Replaces `<TASK_DEFINITION>` in `ci/appspec/api-appspec.yaml` with the registered ARN |
| Create CodeDeploy deployment | `aws deploy create-deployment` with the rendered appspec as `AppSpecContent` |
| Wait | `aws deploy wait deployment-successful` — the step fails if the deployment rolls back |

**Dashboard and worker** use ECS rolling updates. Image updates for those services happen by updating `var.dashboard_image_tag` / `var.worker_image_tag` in Terraform and applying.

### Blue/green deployment flow (API)

```
GitHub push to main
    │
    ├─► ci.yml  (Terraform plan + apply)
    │
    └─► docker.yml  (build + push ARM64 images to ECR)
              │
              └─► deploy.yml
                    │
                    ├── render taskdef-api.json
                    ├── aws ecs register-task-definition  ──► new task def ARN
                    ├── patch appspec-api.yaml with ARN
                    ├── aws deploy create-deployment
                    │       │
                    │       ├── CodeDeploy starts green task set
                    │       ├── green tasks register with url-shortener-api-green TG
                    │       ├── test traffic on :8443 (HTTPS)
                    │       ├── production traffic shifts from :443 to green TG
                    │       │   (ECSLinear10PercentEvery1Minutes — full shift in 10 min)
                    │       ├── auto-rollback on DEPLOYMENT_FAILURE
                    │       └── blue task set terminated after 5 min
                    │
                    └── aws deploy wait deployment-successful
```

### CodeDeploy resources

| Resource | Name |
| -------- | ---- |
| Application | `url-shortener-api` |
| Deployment group | `url-shortener-api` |
| Deployment config | `CodeDeployDefault.ECSLinear10PercentEvery1Minutes` |
| Blue target group | `url-shortener-api` (port 8080) |
| Green target group | `url-shortener-api-green` (port 8080) |
| Production listener | ALB `:443` HTTPS |
| Test listener | ALB `:8443` HTTPS |

Terraform source: `infra/modules/ecs/codedeploy.tf`, `infra/modules/ecs/main.tf`.

### Revision files

| File | Purpose |
| ---- | ------- |
| `ci/taskdef/api-taskdef.json` | Task definition template with `${VAR}` placeholders |
| `ci/appspec/api-appspec.yaml` | AppSpec with `<TASK_DEFINITION>` placeholder |
| `ci/docker/render_taskdef.py` | Substitutes env vars into the task definition template; fails fast on any missing variable |

---

## Environment variables and secrets

### GitHub repository secrets

| Secret | Value |
| ------ | ----- |
| `AWS_TERRAFORM_ROLE_ARN` | ARN of the GitHub OIDC role |

### GitHub repository variables

| Variable | Example |
| -------- | ------- |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `my-27-state-bucket` |
| `TF_STATE_KEY` | `url-shortener-infra/terraform.tfstate` |
| `TF_BOOTSTRAP_STATE_KEY` | `url-shortener-ecr/terraform.tfstate` |
| `TF_IN_AUTOMATION` | `true` |

Inject values with:

```bash
cp .env.example .env   # fill in values
scripts/configure_github_actions_vars.sh --repo OWNER/REPO
```

### render_taskdef.py required environment variables

These are set automatically in the deploy workflow from computed values:

| Variable | Source |
| -------- | ------ |
| `IMAGE_URI` | ECR registry URL + image tag |
| `AWS_REGION` | `vars.AWS_REGION` |
| `EXECUTION_ROLE_ARN` | `arn:aws:iam::<account>:role/url-shortener-ecs-task-execution-role` |
| `TASK_ROLE_ARN` | `arn:aws:iam::<account>:role/url-shortener-api-task-role` |
| `DATABASE_URL_ARN` | `arn:aws:ssm:<region>:<account>:parameter/url-shortener/database_url` |
| `SQS_QUEUE_URL_ARN` | `arn:aws:ssm:<region>:<account>:parameter/url-shortener/sqs_queue_url` |
| `REDIS_URL_ARN` | `arn:aws:ssm:<region>:<account>:parameter/url-shortener/redis_url` |
| `LOG_GROUP` | `/ecs/api` |

---

## Terraform outputs used by deploy automation

Run `terraform output` in `infra/` to retrieve all values needed for deploy scripts or to verify the setup:

```bash
cd infra
terraform output
```

Key outputs:

| Output | Used for |
| ------ | -------- |
| `codedeploy_app_name` | `--application-name` in `aws deploy create-deployment` |
| `codedeploy_deployment_group_name` | `--deployment-group-name` |
| `ecs_task_execution_role_arn` | `EXECUTION_ROLE_ARN` |
| `api_task_role_arn` | `TASK_ROLE_ARN` |
| `database_url_parameter_arn` | `DATABASE_URL_ARN` |
| `sqs_queue_url_parameter_arn` | `SQS_QUEUE_URL_ARN` |
| `redis_url_parameter_arn` | `REDIS_URL_ARN` |
| `api_log_group` | `LOG_GROUP` |
| `ecr_api_repo_url` | Base URL for `IMAGE_URI` |
