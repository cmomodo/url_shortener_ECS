output "cluster_name" {
  value       = aws_ecs_cluster.main_cluster.name
  description = "ECS cluster name."
}

output "api_service_name" {
  value       = aws_ecs_service.api.name
  description = "ECS API service name."
}

output "dashboard_service_name" {
  value       = aws_ecs_service.dashboard.name
  description = "ECS dashboard service name."
}

output "worker_service_name" {
  value       = aws_ecs_service.worker.name
  description = "ECS worker service name."
}

output "api_task_family" {
  value       = aws_ecs_task_definition.api.family
  description = "Task definition family for the API service."
}

output "codedeploy_app_name" {
  value       = aws_codedeploy_app.api.name
  description = "CodeDeploy application name for the API blue/green deployments."
}

output "codedeploy_deployment_group_name" {
  value       = aws_codedeploy_deployment_group.api.deployment_group_name
  description = "CodeDeploy deployment group name for the API service."
}
