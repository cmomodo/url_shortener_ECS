# Values needed by deploy automation (GitHub Actions, scripts, etc.) to
# register ECS task definitions and trigger rolling service updates.

# --- ECS identifiers ---
output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "ECS cluster name."
}

output "api_task_family" {
  value       = module.ecs.api_task_family
  description = "ECS task definition family for the API service."
}

output "dashboard_task_family" {
  value       = module.ecs.dashboard_task_family
  description = "ECS task definition family for the dashboard service."
}

output "worker_task_family" {
  value       = module.ecs.worker_task_family
  description = "ECS task definition family for the worker service."
}

output "codedeploy_app_names" {
  value       = module.ecs.codedeploy_app_names
  description = "CodeDeploy application names by blue/green service."
}

output "codedeploy_deployment_group_names" {
  value       = module.ecs.codedeploy_deployment_group_names
  description = "CodeDeploy deployment group names by blue/green service."
}

# --- IAM role ARNs ---
output "ecs_task_execution_role_arn" {
  value       = module.iam.ecs_task_execution_role_arn
  description = "ECS task execution role ARN."
}

output "api_task_role_arn" {
  value       = module.iam.api_task_role_arn
  description = "API task role ARN."
}

output "worker_task_role_arn" {
  value       = module.iam.worker_task_role_arn
  description = "Worker task role ARN."
}

# --- SSM parameter ARNs ---
output "database_url_parameter_arn" {
  value       = module.ssm.database_url_parameter_arn
  description = "SSM parameter ARN for DATABASE_URL."
}

output "sqs_queue_url_parameter_arn" {
  value       = module.ssm.sqs_queue_url_parameter_arn
  description = "SSM parameter ARN for SQS_QUEUE_URL."
}

output "redis_url_parameter_arn" {
  value       = module.ssm.redis_url_parameter_arn
  description = "SSM parameter ARN for REDIS_URL."
}

# --- CloudWatch log group ---
output "api_log_group" {
  value       = module.iam.api_log_group_name
  description = "CloudWatch log group name for the API container."
}

# --- ECR repository URLs ---
output "ecr_api_repo_url" {
  value       = data.aws_ecr_repository.api.repository_url
  description = "ECR repository URL for the API image."
}

output "ecr_dashboard_repo_url" {
  value       = data.aws_ecr_repository.dashboard.repository_url
  description = "ECR repository URL for the dashboard image."
}

output "ecr_worker_repo_url" {
  value       = data.aws_ecr_repository.worker.repository_url
  description = "ECR repository URL for the worker image."
}
