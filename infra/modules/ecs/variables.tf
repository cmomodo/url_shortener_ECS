variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks."
}

variable "api_security_group_id" {
  type        = string
  description = "Security group ID for the API ECS tasks."
}

variable "dashboard_security_group_id" {
  type        = string
  description = "Security group ID for the dashboard ECS tasks."
}

variable "worker_security_group_id" {
  type        = string
  description = "Security group ID for the worker ECS tasks."
}

variable "api_target_group_arn" {
  type        = string
  description = "ARN of the API blue target group."
}

variable "api_green_target_group_arn" {
  type        = string
  description = "ARN of the API green target group."
}

variable "dashboard_target_group_arn" {
  type        = string
  description = "ARN of the dashboard blue target group."
}

variable "dashboard_green_target_group_arn" {
  type        = string
  description = "ARN of the dashboard green target group."
}

variable "api_target_group_name" {
  type        = string
  description = "Name of the API blue target group."
}

variable "api_green_target_group_name" {
  type        = string
  description = "Name of the API green target group."
}

variable "dashboard_target_group_name" {
  type        = string
  description = "Name of the dashboard blue target group."
}

variable "dashboard_green_target_group_name" {
  type        = string
  description = "Name of the dashboard green target group."
}

variable "https_listener_arn" {
  type        = string
  description = "ARN of the HTTPS production listener."
}

variable "api_test_listener_arn" {
  type        = string
  description = "ARN of the API test traffic listener."
}

variable "dashboard_test_listener_arn" {
  type        = string
  description = "ARN of the dashboard test traffic listener."
}

variable "ecs_task_execution_role_arn" {
  type        = string
  description = "IAM role ARN used by ECS to pull images and write logs."
}

variable "api_task_role_arn" {
  type        = string
  description = "IAM role ARN for the API task."
}

variable "worker_task_role_arn" {
  type        = string
  description = "IAM role ARN for the worker task."
}

variable "api_repository_url" {
  type        = string
  description = "ECR repository URL for the API image."
}

variable "dashboard_repository_url" {
  type        = string
  description = "ECR repository URL for the dashboard image."
}

variable "worker_repository_url" {
  type        = string
  description = "ECR repository URL for the worker image."
}

variable "api_image_tag" {
  type        = string
  description = "Image tag for the API task."
}

variable "dashboard_image_tag" {
  type        = string
  description = "Image tag for the dashboard task."
}

variable "worker_image_tag" {
  type        = string
  description = "Image tag for the worker task."
}

variable "database_url_parameter_arn" {
  type        = string
  description = "SSM parameter ARN containing the database URL."
}

variable "sqs_queue_url_parameter_arn" {
  type        = string
  description = "SSM parameter ARN containing the SQS queue URL."
}

variable "redis_url_parameter_arn" {
  type        = string
  description = "SSM parameter ARN containing the Redis URL."
}

variable "codedeploy_service_role_arn" {
  type        = string
  description = "IAM role ARN assumed by CodeDeploy for ECS blue/green deployments."
}
