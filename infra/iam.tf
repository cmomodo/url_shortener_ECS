#cloudwatch log groups
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/api"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.app.arn
}

resource "aws_cloudwatch_log_group" "dashboard" {
  name              = "/ecs/dashboard"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.app.arn
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/worker"
  retention_in_days = 7
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
