# Container-deploy pipeline: GitHub source -> CodeBuild (build/push images and
# render deploy artifacts) -> CodeDeploy blue/green (api) + ECS rolling
# (dashboard, worker).

# --- GitHub connection (authorize once in the console: PENDING -> AVAILABLE) ---
resource "aws_codestarconnections_connection" "github" {
  name          = "url-shortener-github"
  provider_type = "GitHub"
}

# --- Artifact bucket ---
resource "aws_s3_bucket" "artifacts" {
  #checkov:skip=CKV_AWS_18: Pipeline artifact bucket; access logging adds cost with little value here
  #checkov:skip=CKV_AWS_144: Cross-region replication not required for disposable build artifacts
  #checkov:skip=CKV2_AWS_62: Event notifications not required for the artifact bucket
  #checkov:skip=CKV2_AWS_61: Lifecycle configuration is defined separately below
  bucket        = "url-shortener-cicd-artifacts-${var.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.artifact_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts_tls" {
  bucket = aws_s3_bucket.artifacts.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.artifacts.arn,
        "${aws_s3_bucket.artifacts.arn}/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

# --- CodeBuild log group ---
resource "aws_cloudwatch_log_group" "build" {
  #checkov:skip=CKV_AWS_338: Testing environment - 30-day retention is sufficient
  #checkov:skip=CKV_AWS_158: Build logs do not require a CMK in this environment
  name              = "/codebuild/url-shortener-container-build"
  retention_in_days = 30
}

# --- CodeBuild role ---
resource "aws_iam_role" "codebuild" {
  name = "url-shortener-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-permissions"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.build.arn,
          "${aws_cloudwatch_log_group.build.arn}:*"
        ]
      },
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
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
          "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/url-shortener/api",
          "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/url-shortener/dashboard",
          "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/url-shortener/worker"
        ]
      },
      {
        Sid    = "Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Sid    = "ArtifactKms"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [var.artifact_kms_key_arn]
      }
    ]
  })
}

# --- CodeBuild project (ARM, privileged for Docker) ---
resource "aws_codebuild_project" "build" {
  #checkov:skip=CKV_AWS_316: Privileged mode is required to build container images
  name           = "url-shortener-container-build"
  service_role   = aws_iam_role.codebuild.arn
  encryption_key = var.artifact_kms_key_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ECR_API_REPO"
      value = var.ecr_api_repo_url
    }
    environment_variable {
      name  = "ECR_DASHBOARD_REPO"
      value = var.ecr_dashboard_repo_url
    }
    environment_variable {
      name  = "ECR_WORKER_REPO"
      value = var.ecr_worker_repo_url
    }
    environment_variable {
      name  = "EXECUTION_ROLE_ARN"
      value = var.execution_role_arn
    }
    environment_variable {
      name  = "TASK_ROLE_ARN"
      value = var.api_task_role_arn
    }
    environment_variable {
      name  = "DATABASE_URL_ARN"
      value = var.database_url_parameter_arn
    }
    environment_variable {
      name  = "SQS_QUEUE_URL_ARN"
      value = var.sqs_queue_url_parameter_arn
    }
    environment_variable {
      name  = "REDIS_URL_ARN"
      value = var.redis_url_parameter_arn
    }
    environment_variable {
      name  = "LOG_GROUP"
      value = var.api_log_group
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "ci/docker/buildspec.yml"
  }
}

# --- CodePipeline role ---
resource "aws_iam_role" "pipeline" {
  name = "url-shortener-pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "pipeline" {
  name = "pipeline-permissions"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Sid    = "ArtifactKms"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [var.artifact_kms_key_arn]
      },
      {
        Sid      = "UseConnection"
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = [aws_codestarconnections_connection.github.arn]
      },
      {
        Sid    = "StartBuild"
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = [aws_codebuild_project.build.arn]
      },
      {
        Sid    = "CodeDeploy"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "EcsDeploy"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:TagResource"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "PassTaskRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          var.execution_role_arn,
          var.api_task_role_arn,
          var.worker_task_role_arn
        ]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      }
    ]
  })
}

# --- Pipeline ---
resource "aws_codepipeline" "container_deploy" {
  name     = "url-shortener-container-deploy"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket

    encryption_key {
      id   = var.artifact_kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repo
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["build_out"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployApi"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["build_out"]
      run_order       = 1

      configuration = {
        ApplicationName                = var.codedeploy_app_name
        DeploymentGroupName            = var.codedeploy_deployment_group_name
        TaskDefinitionTemplateArtifact = "build_out"
        TaskDefinitionTemplatePath     = "taskdef-api.json"
        AppSpecTemplateArtifact        = "build_out"
        AppSpecTemplatePath            = "appspec-api.yaml"
      }
    }

    action {
      name            = "DeployDashboard"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_out"]
      run_order       = 1

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.dashboard_service_name
        FileName    = "imagedefinitions-dashboard.json"
      }
    }

    action {
      name            = "DeployWorker"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_out"]
      run_order       = 1

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.worker_service_name
        FileName    = "imagedefinitions-worker.json"
      }
    }
  }
}
