variable "aws_region" {
  type        = string
  description = "AWS region for the pipeline resources."
}

variable "account_id" {
  type        = string
  description = "AWS account ID (used for unique bucket naming and ARNs)."
}

variable "github_repo" {
  type        = string
  description = "Full GitHub repository ID, e.g. owner/name."
}

variable "github_branch" {
  type        = string
  description = "Git branch the pipeline tracks."
}

variable "artifact_kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt the pipeline artifact bucket."
}

variable "ecr_api_repo_url" {
  type        = string
  description = "ECR repository URL for the API image."
}

variable "ecr_dashboard_repo_url" {
  type        = string
  description = "ECR repository URL for the dashboard image."
}

variable "ecr_worker_repo_url" {
  type        = string
  description = "ECR repository URL for the worker image."
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name."
}

variable "dashboard_service_name" {
  type        = string
  description = "ECS dashboard service name (rolling deploy)."
}

variable "worker_service_name" {
  type        = string
  description = "ECS worker service name (rolling deploy)."
}

variable "codedeploy_app_name" {
  type        = string
  description = "CodeDeploy application name for the API blue/green deployment."
}

variable "codedeploy_deployment_group_name" {
  type        = string
  description = "CodeDeploy deployment group name for the API service."
}

variable "execution_role_arn" {
  type        = string
  description = "ECS task execution role ARN (passed when registering task definitions)."
}

variable "api_task_role_arn" {
  type        = string
  description = "API task role ARN."
}

variable "worker_task_role_arn" {
  type        = string
  description = "Worker task role ARN."
}

variable "database_url_parameter_arn" {
  type        = string
  description = "SSM parameter ARN for the database URL (rendered into the API task definition)."
}

variable "sqs_queue_url_parameter_arn" {
  type        = string
  description = "SSM parameter ARN for the SQS queue URL."
}

variable "redis_url_parameter_arn" {
  type        = string
  description = "SSM parameter ARN for the Redis URL."
}

variable "api_log_group" {
  type        = string
  description = "CloudWatch log group for the API container."
  default     = "/ecs/api"
}
