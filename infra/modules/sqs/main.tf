#primary queue
resource "aws_sqs_queue" "terraform_queue" {
  name                              = "primary_queue"
  delay_seconds                     = 90
  max_message_size                  = 2048
  message_retention_seconds         = 86400
  receive_wait_time_seconds         = 10
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.secondary_queue_deadletter.arn
    maxReceiveCount     = 4
  })

  tags = {
    Environment = "production"
  }
}

resource "aws_sqs_queue_policy" "terraform_queue" {
  queue_url = aws_sqs_queue.terraform_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "url-shortener-primary-queue"
    Statement = [
      {
        Sid    = "AllowApiTaskSend"
        Effect = "Allow"
        Principal = {
          AWS = var.api_task_role_arn
        }
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
        ]
        Resource = aws_sqs_queue.terraform_queue.arn
      },
      {
        Sid    = "AllowWorkerTaskConsume"
        Effect = "Allow"
        Principal = {
          AWS = var.worker_task_role_arn
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
        ]
        Resource = aws_sqs_queue.terraform_queue.arn
      },
    ]
  })
}

#sqs queue for dead letter
resource "aws_sqs_queue" "secondary_queue_deadletter" {
  name                              = "backup-queue"
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300
}

#redrive pollicy
resource "aws_sqs_queue_redrive_allow_policy" "terraform_queue_redrive_allow_policy" {
  queue_url = aws_sqs_queue.secondary_queue_deadletter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.terraform_queue.arn]
  })
}
