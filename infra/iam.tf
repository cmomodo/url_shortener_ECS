#cloudwatch log groups
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowSQS"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sqs.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowRDS"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["rds.${data.aws_region.current.region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_cloudwatch_log_group" "api" {
  #checkov:skip=CKV_AWS_338: Testing environment — 30-day retention is sufficient, 1-year retention adds unnecessary cost
  name              = "/ecs/api"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.app.arn
}

resource "aws_cloudwatch_log_group" "dashboard" {
  #checkov:skip=CKV_AWS_338: Testing environment — 30-day retention is sufficient, 1-year retention adds unnecessary cost
  name              = "/ecs/dashboard"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.app.arn
}

resource "aws_cloudwatch_log_group" "worker" {
  #checkov:skip=CKV_AWS_338: Testing environment — 30-day retention is sufficient, 1-year retention adds unnecessary cost
  name              = "/ecs/worker"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.app.arn
}

#iam role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "url-shortener-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Default key for SSM SecureString parameters (used by /url-shortener/* SecureStrings).
data "aws_kms_key" "ssm" {
  key_id = "alias/aws/ssm"
}

resource "aws_iam_role_policy" "ecs_ssm_policy" {
  name = "ecs-ssm-read"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameters", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:us-east-1:*:parameter/url-shortener/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:Encrypt",
          "kms:CreateGrant"
        ]
        Resource = [
          data.aws_kms_key.ssm.arn,
          aws_kms_key.app.arn
        ]
      }
    ]
  })
}

#iam role for the api task
resource "aws_iam_role" "api_task_role" {
  name = "url-shortener-api-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "api_task_sqs_policy" {
  name = "api-send-click-events"
  role = aws_iam_role.api_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.terraform_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.app.arn
      }
    ]
  })
}

#iam role for worker task
resource "aws_iam_role" "worker_task_role" {
  name = "url-shortener-worker-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "worker_task_sqs_policy" {
  name = "worker-consume-click-events"
  role = aws_iam_role.worker_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.terraform_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.app.arn
      }
    ]
  })
}

# Service role assumed by CodeDeploy to manage ECS blue/green deployments.
resource "aws_iam_role" "codedeploy" {
  name = "url-shortener-codedeploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# --- Deployer policy (attach to your GitHub Actions OIDC role or operator role) ---
# Grants the minimum permissions needed to register task definitions and trigger
# CodeDeploy blue/green deployments for API and dashboard, plus ECS rolling
# deployments for the worker.
resource "aws_iam_policy" "deployer" {
  name        = "url-shortener-deployer"
  description = "Allows building/pushing ECR images, registering ECS task definitions, and deploying services."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/url-shortener/api",
          "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/url-shortener/dashboard",
          "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/url-shortener/worker"
        ]
      },
      {
        Sid    = "RegisterTaskDefinition"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassTaskRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.api_task_role.arn,
          aws_iam_role.worker_task_role.arn
        ]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      },
      {
        Sid    = "ReadEcsServiceState"
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices"
        ]
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/url-shortener",
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/url-shortener/api",
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/url-shortener/dashboard",
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/url-shortener/worker"
        ]
      },
      {
        Sid    = "TriggerCodeDeploy"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = [
          "arn:aws:codedeploy:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:application:url-shortener-api",
          "arn:aws:codedeploy:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:application:url-shortener-dashboard",
          "arn:aws:codedeploy:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:deploymentgroup:url-shortener-api/url-shortener-api",
          "arn:aws:codedeploy:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:deploymentgroup:url-shortener-dashboard/url-shortener-dashboard",
          "arn:aws:codedeploy:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:*"
        ]
      },
      {
        Sid      = "UpdateWorkerService"
        Effect   = "Allow"
        Action   = ["ecs:UpdateService"]
        Resource = "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/url-shortener/worker"
      }
    ]
  })
}


