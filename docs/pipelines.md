## CI/CD Overview

The project uses **GitHub Actions** for automation. All workflows target the
`rollout` branch while we test CodeDeploy blue/green deployments.

| Pipeline | Workflow file | Tracked branch | Mutates AWS? |
| -------- | ------------- | -------------- | ------------ |
| Bootstrap (ECR) | `.github/workflows/bootstrap.yml` | `rollout` | Apply on push/manual |
| Main infra (Terraform) | `.github/workflows/ci.yml` | `rollout` | Apply on push/manual |
| Build images | `.github/workflows/docker.yml` | `rollout` | Push 3 images to ECR; also triggerable manually |
| Deploy services | `.github/workflows/deploy.yml` | `rollout` | Registers task definitions and triggers CodeDeploy |

---

## CI/CD Features

### Concurrency

Terraform workflows use a `concurrency` group with `cancel-in-progress: true`
so only one run per branch and action type is active at a time.

| Workflow | Concurrency group |
| -------- | ----------------- |
| Bootstrap | `bootstrap-<workflow>-<ref>-<plan\|apply>` |
| Main infra (`ci.yml`) | `ci-<workflow>-<ref>-<plan\|apply>` |

### OIDC

All GitHub Actions workflows authenticate to AWS with **OpenID Connect**. There
are no long-lived AWS access keys in GitHub.

1. GitHub Actions requests a short-lived OIDC token.
2. `aws-actions/configure-aws-credentials` exchanges it via `sts:AssumeRoleWithWebIdentity`.
3. The runner assumes `AWS_TERRAFORM_ROLE_ARN`.

### Least Privilege

| Role | Used by | Scope |
| ---- | ------- | ----- |
| `url-shortener-github-terraform` | GitHub Actions | Trust limited to the GitHub repo via OIDC |
| `url-shortener-codedeploy` | CodeDeploy | Managed ECS blue/green deployment permissions |
| `url-shortener-deployer` | Deploy workflow | Register task definitions, pass ECS task roles, and create CodeDeploy deployments |

Roles and policies are defined in `infra/iam.tf`. Attach the deployer policy to
the GitHub OIDC role, or to the operator role that runs deployments.

---

## Bootstrap Pipeline

Workflow: `.github/workflows/bootstrap.yml`

Provisions ECR repositories for `api`, `dashboard`, and `worker`. Run this
before the main infra pipeline because the main stack reads these repositories
as data sources.

| Trigger | Condition | What happens |
| ------- | --------- | ------------ |
| Push to `rollout` | Only `infra-ecr/**`, `modules/ecr/**`, `.github/workflows/bootstrap.yml` | plan -> apply -> idempotency check |
| Pull request to `rollout` | Same path filter | plan only |
| Manual (`workflow_dispatch`) | Always | choose `plan` or `apply` |

State key: `TF_BOOTSTRAP_STATE_KEY` (expected `url-shortener-ecr/terraform.tfstate`).

---

## Main Infra Pipeline

Workflow: `.github/workflows/ci.yml`

Deploys the main AWS stack in `infra/`: VPC, ECS, RDS, ALB, IAM, CodeDeploy,
CloudFront, Route 53, SQS, Redis, and supporting resources.

| Trigger | Condition | What happens |
| ------- | --------- | ------------ |
| Push to `rollout` | Any file change | plan -> apply -> idempotency check |
| Pull request to `rollout` | Any change | plan only |
| Manual (`workflow_dispatch`) | Always | choose `plan` or `apply` |

State key: `TF_STATE_KEY` (expected `url-shortener-infra/terraform.tfstate`).

---

## Container Deploy Pipeline

Two workflows work together to build images and deploy the three ECS services
with CodeDeploy blue/green deployments.

### Step 1: Build And Push

Workflow: `.github/workflows/docker.yml`

Triggered automatically when the CI workflow completes successfully on `rollout`,
or **manually** via `workflow_dispatch` (Actions → Build and Push Docker Images
→ Run workflow).

It builds all three service images for `linux/arm64` in parallel, then pushes
each image to its own ECR repository with an immutable tag.

| Service | Build context | ECR repo |
| ------- | ------------- | -------- |
| `api` | `./app` | `url-shortener/api` |
| `dashboard` | `./services/dashboard` | `url-shortener/dashboard` |
| `worker` | `./services/worker` | `url-shortener/worker` |

Image tag format: `<sha7>-<docker-workflow-run-id>`, for example
`a1b2c3d-12345678901`. The run ID is shared across the matrix jobs, so API,
dashboard, and worker get the same tag in one build.

When triggered via `workflow_dispatch` the SHA is taken from `github.sha`
(the branch HEAD at trigger time) instead of `github.event.workflow_run.head_sha`.

### Step 2: CodeDeploy Blue/Green

Workflow: `.github/workflows/deploy.yml`

Triggered when `docker.yml` completes successfully on `rollout`. It can also be
run manually with a specific image tag.

The deploy job runs as a matrix for `api`, `dashboard`, and `worker`:

| Step | What happens |
| ---- | ------------ |
| Resolve image tag | Reconstructs the immutable Docker workflow tag, or uses the manual `image_tag` |
| Read current task definition | Calls `aws ecs describe-services` and `aws ecs describe-task-definition` |
| Render new task definition | Keeps the existing task settings and swaps only the container image |
| Register task definition | Calls `aws ecs register-task-definition` |
| Render AppSpec | Generates the ECS CodeDeploy AppSpec with the new task definition ARN |
| Create deployment | Calls `aws deploy create-deployment` for the service deployment group |
| Wait | Calls `aws deploy wait deployment-successful` |

### Blue/Green Flow

```text
GitHub push to rollout
    |
    +-- ci.yml      Terraform plan + apply
          |
          +-- docker.yml   build + push api/dashboard/worker images
                |
                +-- deploy.yml
                      |
                      +-- api CodeDeploy blue/green
                      +-- dashboard CodeDeploy blue/green
                      +-- worker ECS rolling update
```

Each CodeDeploy-backed service has:

| Service | Blue target group | Green target group | Production route | Test route |
| ------- | ----------------- | ------------------ | ---------------- | ---------- |
| `api` | `url-shortener-api` | `url-shortener-api-green` | ALB HTTPS `:443` default route | ALB HTTPS `:8443` |
| `dashboard` | `url-shortener-dashboard` | `url-shortener-dashboard-green` | Dashboard path listener rule on `:443` | ALB HTTPS `:8444` |

The worker does not receive user traffic, so it uses the default ECS deployment
controller and the deploy workflow updates the worker service directly after
registering a new task definition.

---

## Environment Variables And Secrets

### GitHub Repository Secrets

| Secret | Value |
| ------ | ----- |
| `AWS_TERRAFORM_ROLE_ARN` | ARN of the GitHub OIDC role |

### GitHub Repository Variables

| Variable | Example |
| -------- | ------- |
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | `my-27-state-bucket` |
| `TF_STATE_KEY` | `url-shortener-infra/terraform.tfstate` |
| `TF_BOOTSTRAP_STATE_KEY` | `url-shortener-ecr/terraform.tfstate` |
| `TF_IN_AUTOMATION` | `true` |

Inject values with:

```bash
cp .env.example .env
scripts/configure_github_actions_vars.sh --repo OWNER/REPO
```

---

## Terraform Outputs

Run `terraform output` in `infra/` to retrieve values used for verification:

```bash
cd infra
terraform output
```

Key outputs include `ecs_cluster_name`, `codedeploy_app_names`,
`codedeploy_deployment_group_names`, task family names, task role ARNs, SSM
parameter ARNs, log group names, and ECR repository URLs.
