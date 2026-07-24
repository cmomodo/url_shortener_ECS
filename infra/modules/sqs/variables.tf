variable "kms_key_id" {
  type        = string
  description = "ID of the application CMK used to encrypt the queues"
}

variable "api_task_role_arn" {
  type        = string
  description = "ARN of the API task role allowed to send messages"
}

variable "worker_task_role_arn" {
  type        = string
  description = "ARN of the worker task role allowed to consume messages"
}
