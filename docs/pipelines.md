we have already decided how to go about two of our workflows. codebuild cant directly deploy Terraform.

we are going to use built in github actions to deploy Terraform.

then we will use codedeploy via blue/green deployment for the containers. API/ dashboard will be deployed together, and the worker will be deployed separately.

we will create roles that are least privileged and will only be used for the pipeline.

## How the CI Pipeline Works (GitHub Actions)

The CI pipeline is defined in `.github/workflows/ci.yml` and is responsible for deploying the AWS infrastructure using Terraform. It does **not** build or deploy containers — that is handled by CodeBuild/CodePipeline.

### When it runs

| Trigger | What happens |
|---|---|
| Push to `main` | Runs `terraform plan` to validate the infrastructure changes |
| Pull request to `main` | Runs `terraform plan` so you can review changes before merging |
| Manual (`workflow_dispatch`) | You choose to run either `plan` or `apply` from the GitHub Actions UI |

Only a manual `apply` will actually make changes to your AWS infrastructure. Pushes and PRs always run `plan` only — they never mutate infrastructure.

### Steps it runs in order

1. **Checkout** — pulls the repo code onto the runner
2. **Setup Terraform** — installs Terraform v1.9.0 on the runner
3. **Check formatting** — runs `terraform fmt -check` and fails if any `.tf` files are not formatted correctly
4. **Configure AWS credentials** — assumes the `AWS_TERRAFORM_ROLE_ARN` IAM role via OIDC (no long-lived access keys needed)
5. **Terraform init** — connects to the S3 remote state backend with DynamoDB locking enabled
6. **Terraform validate** — checks that the Terraform configuration is syntactically valid
7. **Terraform plan** — previews what changes would be made (runs on push/PR and manual `plan`)
8. **Terraform apply** — applies the changes to AWS (only runs on manual `apply`)
9. **Verify idempotency** — runs `terraform plan` again after apply and fails if there are any unexpected remaining changes

### Concurrency

Only one run per branch/action can run at a time. If a new run is triggered while one is already in progress, the in-progress run is cancelled.

---

## What CodeBuild Does

CodeBuild is triggered by CodePipeline after a push to the tracked branch. It is responsible for building the Docker images for all three services and producing the deployment artifacts that the deploy stage consumes.

The buildspec is defined in `ci/docker/buildspec.yml` and runs in three phases:

### Phase 1 — pre_build
- Authenticates with Amazon ECR using the CodeBuild role
- Generates a unique image tag from the first 8 characters of the git commit SHA plus a timestamp (e.g. `a1b2c3d4-20260603120000`)

### Phase 2 — build
- Builds three Docker images natively on an ARM64 host (matching the ARM64 Fargate tasks):
  - `api` — built from `./app`
  - `dashboard` — built from `./services/dashboard`
  - `worker` — built from `./services/worker`
- Pushes all three images to their respective ECR repositories with the immutable tag

### Phase 3 — post_build
Renders the deployment artifacts that the pipeline's deploy stage needs:

| Artifact | Used by | Purpose |
|---|---|---|
| `taskdef-api.json` | CodeDeploy (blue/green) | API task definition with the new image URI injected |
| `appspec-api.yaml` | CodeDeploy (blue/green) | Tells CodeDeploy how to shift traffic to the new task set |
| `imagedefinitions-dashboard.json` | ECS rolling deploy | Points the dashboard service to the new image |
| `imagedefinitions-worker.json` | ECS rolling deploy | Points the worker service to the new image |

These four files are passed as artifacts to the Deploy stage of CodePipeline, which then triggers the deployments in parallel.

## Creating Pipeline Roles

The pipeline uses two IAM roles that are automatically created via Terraform:

### 1. CodeBuild Role (`url-shortener-codebuild`)
This role allows CodeBuild to:
- Write logs to CloudWatch
- Authenticate with ECR and push images
- Access the artifact bucket and KMS key

### 2. CodePipeline Role (`url-shortener-pipeline`)
This role allows CodePipeline to:
- Access artifacts in S3 with KMS encryption
- Use the GitHub connection
- Trigger CodeBuild projects
- Execute CodeDeploy deployments
- Update ECS services
- Pass task roles to ECS tasks

### Creating the Roles

The roles are defined in Terraform in `/infra/modules/cicd/main.tf`. To deploy these roles:

```bash
# Navigate to the infrastructure directory
cd infra

# Initialize Terraform (if not already done)
terraform init

# Plan the deployment to verify the roles will be created
terraform plan

# Apply the configuration to create the roles
terraform apply
```

**Note:** These roles are automatically created as part of the CICD module and do not require separate manual creation. They are least-privileged and scoped only to the resources needed for the pipeline.

## Pipeline Environment Variables

### GitHub Actions (Terraform pipeline)

These variables are set in `.github/workflows/ci.yml`. Update them to match your environment before running the pipeline:

| Variable | Value | Description |
|---|---|---|
| `AWS_REGION` | `us-east-1` | AWS region where resources are deployed |
| `TF_STATE_BUCKET` | `my-27-state-bucket` | S3 bucket name for Terraform remote state |
| `TF_STATE_KEY` | `url-shortener-main/terraform.tfstate` | Path/key for the state file in the bucket |
| `TF_LOCK_TABLE` | `terraform-state-locks` | DynamoDB table name for Terraform state locking |
| `TF_IN_AUTOMATION` | `"true"` | Disables interactive prompts in CI |

The following must be added as a **GitHub secret** (Settings > Secrets and variables > Actions):

| Secret | Description |
|---|---|
| `AWS_TERRAFORM_ROLE_ARN` | ARN of the IAM role GitHub assumes via OIDC to run Terraform. Created when you run `terraform apply`. |

### CodeBuild (container build pipeline)

These variables are **injected automatically by Terraform** when the CICD module is applied. No manual setup is required.

| Variable | Source | Description |
|---|---|---|
| `AWS_DEFAULT_REGION` | `var.aws_region` | AWS region |
| `AWS_ACCOUNT_ID` | `var.account_id` | AWS account ID |
| `ECR_API_REPO` | ECR repository URL | URL of the API ECR repository |
| `ECR_DASHBOARD_REPO` | ECR repository URL | URL of the dashboard ECR repository |
| `ECR_WORKER_REPO` | ECR repository URL | URL of the worker ECR repository |
| `EXECUTION_ROLE_ARN` | ECS task execution role | ARN of the ECS task execution role |
| `TASK_ROLE_ARN` | API task role | ARN of the API task role |
| `DATABASE_URL_ARN` | SSM parameter ARN | ARN of the database URL SSM parameter |
| `SQS_QUEUE_URL_ARN` | SSM parameter ARN | ARN of the SQS queue URL SSM parameter |
| `REDIS_URL_ARN` | SSM parameter ARN | ARN of the Redis URL SSM parameter |
| `LOG_GROUP` | CloudWatch log group | Log group for the API container (default: `/ecs/api`) |
