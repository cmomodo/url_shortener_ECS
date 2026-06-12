we have already decided how to go about two of our workflows. codebuild cant directly deploy Terraform.

we are going to use built in github actions to deploy Terraform.

then we will use codedeploy via blue/green deployment for the containers. API/ dashboard will be deployed together, and the worker will be deployed separately.

we will create roles that are least privileged and will only be used for the pipeline.

## CI/CD features

### Concurrency

GitHub Actions workflows use a `concurrency` group with `cancel-in-progress: true` so only one run per branch and action type is active at a time. A newer push cancels a stale in-flight run instead of stacking competing Terraform applies or plans.

| Workflow | Concurrency group | Notes |
| -------- | ----------------- | ----- |
| Bootstrap | `bootstrap-<workflow>-<ref>-<plan\|apply>` | Push and manual `apply` share the `apply` slot; PRs and manual `plan` use `plan` |
| Main infra (`ci.yml`) | `ci-<workflow>-<ref>-<plan\|apply>` | Push always maps to `apply`; PRs and manual runs use `plan` or the selected input |

The container CodePipeline has **no** concurrency guard in Terraform. Rapid pushes queue separate pipeline executions; CodePipeline runs them sequentially per pipeline, but overlapping builds can still occur under heavy churn.

### OIDC

Terraform pipelines authenticate to AWS with **OpenID Connect** — no long-lived access keys in GitHub.

1. GitHub Actions requests a short-lived OIDC token (`permissions: id-token: write` in both workflows).
2. `aws-actions/configure-aws-credentials` exchanges that token for temporary AWS credentials by calling `sts:AssumeRoleWithWebIdentity`.
3. The runner assumes `AWS_TERRAFORM_ROLE_ARN` (secret), typically `url-shortener-github-terraform`.

Setup (once per account):

- Create the GitHub OIDC provider (`https://token.actions.githubusercontent.com`) — see `scripts/setup_oidc.sh`.
- Create the Terraform role with a trust policy scoped to this repository (and optionally branch/environment).
- Store the role ARN as the `AWS_TERRAFORM_ROLE_ARN` secret.

The **container pipeline does not use OIDC**. It pulls source through CodeStar Connections and runs under AWS service roles (CodePipeline, CodeBuild, CodeDeploy).

### Least privilege

Each automation path uses dedicated IAM roles with scoped inline policies (or AWS-managed policies where appropriate):

| Role | Used by | Scope |
| ---- | ------- | ----- |
| `url-shortener-github-terraform` | GitHub Actions (bootstrap + main infra) | Trust limited to the GitHub repo via OIDC; permissions for Terraform (bootstrap script attaches `AdministratorAccess` today — tighten for production) |
| `url-shortener-codebuild` | CodeBuild | CloudWatch logs for the build project; ECR push to the three `url-shortener/*` repos only; read/write on the pipeline artifact bucket and its KMS key |
| `url-shortener-pipeline` | CodePipeline | Artifact bucket + KMS; CodeStar connection; start the single CodeBuild project; CodeDeploy and ECS deploy actions; `iam:PassRole` only for the ECS execution and task roles, with `PassedToService = ecs-tasks.amazonaws.com` |
| `url-shortener-codedeploy` | CodeDeploy (API blue/green) | `AWSCodeDeployRoleForECS` managed policy |

Terraform state access can be further restricted with `terraform_state_access_role_arns` and `terraform_state_enforce_allowlist` on the state bucket (`infra/state_bucket_policy.tf`), so only listed role ARNs (for example the GitHub OIDC role) can read or write state.

Roles are defined in:

- `infra/modules/cicd/main.tf` — CodeBuild and CodePipeline
- `infra/iam.tf` — CodeDeploy service role
- `scripts/setup_oidc.sh` — GitHub Terraform role (manual bootstrap)

### Artifacts

Artifacts carry outputs between pipeline stages and preserve evidence for review.

**GitHub Actions (Terraform)**

| Artifact | When uploaded | Retention | Purpose |
| -------- | ------------- | --------- | ------- |
| `tfplan` + `tfplan.txt` | Every plan run (PR, manual `plan`, and pre-apply on push) | 14 days | Human-readable plan for review; binary plan reused for apply on push |

Apply always runs against the **saved** `tfplan` from the same workflow run (plan-then-apply), not a fresh implicit apply.

**CodePipeline (container deploy)**

| Stage | Artifact | Store |
| ----- | -------- | ----- |
| Source | `source` — repo zip from GitHub | S3 bucket `url-shortener-cicd-artifacts-<account_id>`, SSE-KMS, versioning enabled |
| Build | `build_out` — deploy manifests from CodeBuild | Same bucket |
| Deploy | Consumes `build_out` in parallel deploy actions | Not stored separately |

CodeBuild `post_build` files inside `build_out`:

| File | Consumer |
| ---- | -------- |
| `taskdef-api.json` | CodeDeploy (API) |
| `appspec-api.yaml` | CodeDeploy (API) |
| `appspec-dashboard.yaml` | Future CodeDeploy dashboard deployment |
| `appspec-worker.yaml` | Future CodeDeploy worker deployment |
| `imagedefinitions-dashboard.json` | ECS rolling (dashboard) |
| `imagedefinitions-worker.json` | ECS rolling (worker) |

Artifact bucket lifecycle: objects expire after 30 days; noncurrent versions expire after 30 days.

### SHA digest

Images and infrastructure changes are tied to immutable, traceable identifiers.

**Git commit SHA in image tags**

CodeBuild sets the image tag from the pipeline source revision:

```text
IMAGE_TAG="${CODEBUILD_RESOLVED_SOURCE_VERSION:0:8}-$(date +%Y%m%d%H%M%S)"
```

Example: `a1b2c3d4-20260603120000` — first 8 characters of the Git commit SHA plus a UTC timestamp. The same tag is applied to all three service images in a single pipeline run so api, dashboard, and worker stay in sync.

`CODEBUILD_RESOLVED_SOURCE_VERSION` is the full commit SHA passed from the CodePipeline Source stage.

**ECR image digest (SHA256)**

When CodeBuild pushes to ECR, each image receives an ECR **content digest** (`sha256:…`) in addition to the tag. ECR repositories are configured with `image_tag_mutability = "IMMUTABLE"` (`modules/ecr/main.tf`), so a tag cannot be overwritten — pushing the same tag twice fails, which prevents silent drift.

Deploy artifacts reference `repository_url:tag` (for example in `taskdef-api.json` and `imagedefinitions-*.json`). ECS and CodeDeploy resolve that tag to the digest at deployment time, so the running task is pinned to the exact image bits that were pushed in that build.

**Terraform plan artifact**

The saved `tfplan` file is the apply contract for infra changes: the apply step uses that binary plan, and the post-apply idempotency check confirms no unexpected diff remains.

---

## How triggers work

The project has **three independent delivery paths**. They do not call each other; each one watches Git (or is started manually) on its own rules.

| Pipeline | Defined in | Tracked branch | Path filter | Auto on push | Manual trigger | Mutates AWS? |
| -------- | ---------- | -------------- | ----------- | ------------ | -------------- | ------------ |
| Bootstrap (ECR) | `.github/workflows/bootstrap.yml` | `securityn` | Yes — only `infra-ecr/**`, `modules/ecr/**`, `.github/workflows/bootstrap.yml` | Plan + apply when matched paths change | `workflow_dispatch` — choose `plan` or `apply` | Apply runs only |
| Main infra (Terraform) | `.github/workflows/ci.yml` | `securityn` | No — **any** file change on the branch | Plan + apply on every push | `workflow_dispatch` — choose `plan` or `apply` | Apply runs only |
| Container deploy | `infra/modules/cicd/main.tf` (`url-shortener-container-deploy`) | `securityn` (via `var.github_branch`) | No — **any** commit on the tracked branch | Full pipeline: Source → Build → Deploy | Start execution in the CodePipeline console (or AWS CLI) | Yes — builds images and deploys ECS |

**Tracked branch:** All three paths target the same branch today (`securityn`). The container pipeline reads `var.github_branch` in Terraform (default `securityn`); the GitHub Actions workflows hard-code the same branch in their `on:` blocks.

**Pull requests:** Only the two GitHub Actions workflows run on PRs, and both are **plan-only** — they never apply. CodePipeline does not run for pull requests.

**Destroy:** There is no automated destroy workflow today. Teardown is expected to be a deliberate manual step (for example a future `workflow_dispatch` Terraform destroy job). Nothing in the repo triggers destroy on push.

### What a single `git push` can start

Because path filters differ, one push may start one, two, or all three pipelines:


| Changed files | Bootstrap | Main infra (`ci.yml`) | Container (`CodePipeline`) |
| ------------- | --------- | --------------------- | ---------------------------- |
| `app/**`, `services/**`, `ci/**` only | No | Yes — Terraform apply | Yes — build + deploy |
| `infra/**` only (not `infra-ecr`) | No | Yes — Terraform apply | Yes — build + deploy |
| `infra-ecr/**` or `modules/ecr/**` | Yes — Terraform apply | Yes — Terraform apply | Yes — build + deploy |
| Docs/markdown only | No | Yes — Terraform apply | Yes — build + deploy |

A push that only touches bootstrap paths therefore runs **bootstrap apply**, **main infra apply**, and **container build/deploy** in parallel (three separate systems).

### One-time setup that affects triggers

The container pipeline uses a **CodeStar Connections** GitHub link (`url-shortener-github`). Until that connection is authorized in the AWS console (status `PENDING` → `AVAILABLE`), pushes to GitHub will **not** start the container pipeline. Terraform creates the connection; authorization is manual in the console (see output `cicd_github_connection_arn`).

---

## Bootstrap pipeline (GitHub Actions)

Workflow file: `.github/workflows/bootstrap.yml`

Provisions ECR repositories (`url-shortener/api`, `url-shortener/dashboard`, `url-shortener/worker`) in the `infra-ecr` Terraform stack. Run this **before** the main infra pipeline — the main stack reads those repos as data sources and fails to plan if they do not exist.

### When it runs


| Trigger | Condition | What happens |
| ------- | --------- | -------------- |
| Push to `securityn` | Only if the commit changes `infra-ecr/**`, `modules/ecr/**`, or `.github/workflows/bootstrap.yml` | `terraform plan` → upload plan artifact → `terraform apply` → idempotency check |
| Pull request → `securityn` | Same path filter as push | `terraform plan` only; plan uploaded as artifact |
| Manual (`workflow_dispatch`) | Always available from the Actions tab | Input `terraform_action`: `plan` (default) or `apply` |

Pushes and manual `apply` mutate AWS. Pull requests and manual `plan` never apply.

State key: `TF_BOOTSTRAP_STATE_KEY` (expected `url-shortener-ecr/terraform.tfstate`).

---

## Main infra pipeline (GitHub Actions)

Workflow file: `.github/workflows/ci.yml`

Deploys the main AWS stack (`infra/`) with Terraform. It does **not** build or deploy containers — that is handled by CodePipeline → CodeBuild → CodeDeploy/ECS.

### When it runs


| Trigger | Condition | What happens |
| ------- | --------- | -------------- |
| Push to `securityn` | **No path filter** — every push to the branch | `terraform plan` → upload plan artifact → `terraform apply` → idempotency check |
| Pull request → `securityn` | Any PR targeting the branch | `terraform plan` only; plan uploaded as artifact |
| Manual (`workflow_dispatch`) | Always available from the Actions tab | Input `terraform_action`: `plan` (default) or `apply` |

Pushes and manual `apply` mutate AWS. Pull requests and manual `plan` never apply.

State key: `TF_STATE_KEY` (expected `url-shortener-infra/terraform.tfstate`).

### Steps it runs in order

1. **Checkout** — pulls the repo code onto the runner
2. **Setup Terraform** — installs Terraform v1.14.7 on the runner
3. **Check formatting** — runs `terraform fmt -check` and fails if any `.tf` files are not formatted correctly
4. **Configure AWS credentials** — assumes the `AWS_TERRAFORM_ROLE_ARN` IAM role via OIDC (no long-lived access keys needed)
5. **Terraform init** — connects to the S3 remote state backend with native S3 lockfiles enabled
6. **Terraform validate** — checks that the Terraform configuration is syntactically valid
7. **Terraform plan** — previews what changes would be made (runs on push/PR and manual `plan`) and saves both `tfplan` and `tfplan.txt` as workflow artifacts
8. **Terraform apply** — creates a saved `tfplan`, uploads it as an artifact, then applies that exact plan (runs on push or manual `apply`)
9. **Verify idempotency** — runs `terraform plan` again after apply and fails if there are any unexpected remaining changes

See [Concurrency](#concurrency) under CI/CD features.

---

## Container deploy pipeline (CodePipeline)

Terraform: `infra/modules/cicd/main.tf` — pipeline name `url-shortener-container-deploy`.

Orchestrates GitHub source → CodeBuild (build and push images) → deploy (CodeDeploy blue/green for API, ECS rolling for dashboard and worker). This path is entirely in AWS; it does not use GitHub Actions.

### When it runs


| Trigger | Condition | What happens |
| ------- | --------- | -------------- |
| Push to tracked branch | Commit lands on `var.github_branch` (default `securityn`) after the CodeStar GitHub connection is `AVAILABLE` | CodePipeline starts automatically: Source (zip from GitHub) → Build (CodeBuild) → Deploy (parallel CodeDeploy + two ECS updates) |
| Manual | CodePipeline console → **Release change**, or `aws codepipeline start-pipeline-execution` | Re-runs the pipeline on the latest commit already seen on the branch (does not rebuild from a different branch unless that branch is configured in Terraform) |

There is **no path filter**. A documentation-only push still runs a full image build and deployment if it is pushed to the tracked branch.

Repository and branch are set in Terraform:


| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `github_repo` | `cmomodo/url_shortener_ECS` | `FullRepositoryId` for CodeStar Source Connection |
| `github_branch` | `securityn` | Branch the Source stage polls |

CodeBuild is **not** triggered directly by GitHub. It only runs as the Build stage of this pipeline (source type `CODEPIPELINE`).

### Deploy stage (after a successful build)

Three deploy actions run in parallel (`run_order = 1`):


| Action | Provider | Service |
| ------ | -------- | ------- |
| `DeployApi` | CodeDeployToECS | API — blue/green via `url-shortener-api` deployment group |
| `DeployDashboard` | ECS | Dashboard — rolling update from `imagedefinitions-dashboard.json` |
| `DeployWorker` | ECS | Worker — rolling update from `imagedefinitions-worker.json` |

---

## What CodeBuild Does

CodeBuild runs inside the container pipeline's Build stage. It is responsible for building the Docker images for all three services and producing the deployment artifacts that the deploy stage consumes.

The buildspec is defined in `ci/docker/buildspec.yml` and runs in three phases:

### Phase 1 — pre_build

- Authenticates with Amazon ECR using the CodeBuild role
- Generates a unique image tag from the first 8 characters of the git commit SHA plus a timestamp (e.g. `a1b2c3d4-20260603120000`)
- ECR login uses the CodeBuild IAM role (no extra manual step per build). The **GitHub connection** for the pipeline Source stage is separate — that one-time console authorization is required before pushes can trigger the pipeline (see [One-time setup](#one-time-setup-that-affects-triggers) above).

### Phase 2 — build

- Builds three Docker images natively on an ARM64 host (matching the ARM64 Fargate tasks):
  - `api` — built from `./app`
  - `dashboard` — built from `./services/dashboard`
  - `worker` — built from `./services/worker`
- Pushes all three images to their respective ECR repositories with the immutable tag

### Phase 3 — post_build

Renders the deployment artifacts that the pipeline's deploy stage needs:


| Artifact                          | Used by                 | Purpose                                                   |
| --------------------------------- | ----------------------- | --------------------------------------------------------- |
| `taskdef-api.json`                | CodeDeploy (blue/green) | API task definition with the new image URI injected        |
| `appspec-api.yaml`                | CodeDeploy (blue/green) | Tells CodeDeploy how to shift API traffic                  |
| `appspec-dashboard.yaml`          | Future CodeDeploy deploy | Dashboard AppSpec for a dashboard CodeDeploy action        |
| `appspec-worker.yaml`             | Future CodeDeploy deploy | Worker AppSpec for a worker CodeDeploy action              |
| `imagedefinitions-dashboard.json` | ECS rolling deploy       | Points the dashboard service to the new image              |
| `imagedefinitions-worker.json`    | ECS rolling deploy       | Points the worker service to the new image                 |


These files are passed as artifacts to the Deploy stage of CodePipeline, which then triggers the deployments in parallel.

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

The workflows read their Terraform configuration from GitHub Actions repository variables and secrets. Do not hardcode real bucket names, state keys, account IDs, or role ARNs in committed files.

Create a local `.env` from the committed template:

```bash
cp .env.example .env
```

Fill in these values in `.env`:

- `AWS_REGION`: AWS region where resources are deployed.
- `TF_STATE_BUCKET`: S3 bucket name for Terraform remote state.
- `TF_STATE_KEY`: state key for the main infrastructure stack.
- `TF_BOOTSTRAP_STATE_KEY`: state key for the bootstrap ECR stack.
- `TF_IN_AUTOMATION`: set to `true` for CI.
- `AWS_TERRAFORM_ROLE_ARN`: IAM role ARN GitHub assumes via OIDC.

Then inject the values into GitHub Actions:

```bash
scripts/configure_github_actions_vars.sh --repo OWNER/REPO
```

The script stores `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_KEY`, `TF_BOOTSTRAP_STATE_KEY`, and `TF_IN_AUTOMATION` as repository variables. It stores `AWS_TERRAFORM_ROLE_ARN` as a repository secret.

Terraform uses S3 native state locking with `use_lockfile=true`, so no DynamoDB lock table is required.


### CodeBuild (container build pipeline)

These variables are **injected automatically by Terraform** when the CICD module is applied. No manual setup is required.


| Variable             | Source                  | Description                                           |
| -------------------- | ----------------------- | ----------------------------------------------------- |
| `AWS_DEFAULT_REGION` | `var.aws_region`        | AWS region                                            |
| `AWS_ACCOUNT_ID`     | `var.account_id`        | AWS account ID                                        |
| `ECR_API_REPO`       | ECR repository URL      | URL of the API ECR repository                         |
| `ECR_DASHBOARD_REPO` | ECR repository URL      | URL of the dashboard ECR repository                   |
| `ECR_WORKER_REPO`    | ECR repository URL      | URL of the worker ECR repository                      |
| `EXECUTION_ROLE_ARN` | ECS task execution role | ARN of the ECS task execution role                    |
| `TASK_ROLE_ARN`      | API task role           | ARN of the API task role                              |
| `DATABASE_URL_ARN`   | SSM parameter ARN       | ARN of the database URL SSM parameter                 |
| `SQS_QUEUE_URL_ARN`  | SSM parameter ARN       | ARN of the SQS queue URL SSM parameter                |
| `REDIS_URL_ARN`      | SSM parameter ARN       | ARN of the Redis URL SSM parameter                    |
| `LOG_GROUP`          | CloudWatch log group    | Log group for the API container (default: `/ecs/api`) |
