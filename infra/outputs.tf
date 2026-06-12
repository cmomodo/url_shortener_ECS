# Values needed by deploy automation (GitHub Actions, scripts, etc.) to
# render the task definition template and trigger a CodeDeploy deployment.

# --- ECS / CodeDeploy identifiers ---
output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "ECS cluster name."
}

output "codedeploy_app_name" {
  value       = module.ecs.codedeploy_app_name
  description = "CodeDeploy application name."
}

output "codedeploy_deployment_group_name" {
  value       = module.ecs.codedeploy_deployment_group_name
  description = "CodeDeploy deployment group name."
}

output "api_task_family" {
  value       = module.ecs.api_task_family
  description = "ECS task definition family for the API service."
}

# --- IAM role ARNs (passed to render_taskdef.py as EXECUTION_ROLE_ARN / TASK_ROLE_ARN) ---
output "ecs_task_execution_role_arn" {
  value       = aws_iam_role.ecs_task_execution_role.arn
  description = "ECS task execution role ARN."
}

output "api_task_role_arn" {
  value       = aws_iam_role.api_task_role.arn
  description = "API task role ARN."
}

# --- SSM parameter ARNs (passed to render_taskdef.py as *_ARN env vars) ---
output "database_url_parameter_arn" {
  value       = aws_ssm_parameter.database_url.arn
  description = "SSM parameter ARN for DATABASE_URL."
}

output "sqs_queue_url_parameter_arn" {
  value       = aws_ssm_parameter.sqs_queue_url.arn
  description = "SSM parameter ARN for SQS_QUEUE_URL."
}

output "redis_url_parameter_arn" {
  value       = aws_ssm_parameter.redis_url.arn
  description = "SSM parameter ARN for REDIS_URL."
}

# --- CloudWatch log group ---
output "api_log_group" {
  value       = aws_cloudwatch_log_group.api.name
  description = "CloudWatch log group name for the API container (LOG_GROUP env var)."
}

# --- ECR repository URLs ---
output "ecr_api_repo_url" {
  value       = data.aws_ecr_repository.api.repository_url
  description = "ECR repository URL for the API image."
}
