output "ecs_task_execution_role_arn" {
  value       = aws_iam_role.ecs_task_execution_role.arn
  description = "ECS task execution role ARN."
}

output "api_task_role_arn" {
  value       = aws_iam_role.api_task_role.arn
  description = "API task role ARN."
}

output "worker_task_role_arn" {
  value       = aws_iam_role.worker_task_role.arn
  description = "Worker task role ARN."
}

output "codedeploy_role_arn" {
  value       = aws_iam_role.codedeploy.arn
  description = "CodeDeploy service role ARN."
}

output "deployer_policy_arn" {
  value       = aws_iam_policy.deployer.arn
  description = "Deployer IAM policy ARN (attach to CI/CD or operator role)."
}

output "api_log_group_name" {
  value       = aws_cloudwatch_log_group.api.name
  description = "CloudWatch log group name for the API container."
}

output "dashboard_log_group_name" {
  value       = aws_cloudwatch_log_group.dashboard.name
  description = "CloudWatch log group name for the dashboard container."
}

output "worker_log_group_name" {
  value       = aws_cloudwatch_log_group.worker.name
  description = "CloudWatch log group name for the worker container."
}
