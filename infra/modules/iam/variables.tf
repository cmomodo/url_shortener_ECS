variable "kms_key_arn" {
  type        = string
  description = "ARN of the application CMK used for logs, SSM, and SQS encryption"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the click-events SQS queue the api/worker task roles act on"
}
