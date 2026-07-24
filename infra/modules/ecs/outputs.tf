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

output "dashboard_task_family" {
  value       = aws_ecs_task_definition.dashboard.family
  description = "Task definition family for the dashboard service."
}

output "worker_task_family" {
  value       = aws_ecs_task_definition.worker.family
  description = "Task definition family for the worker service."
}

output "codedeploy_app_names" {
  value = {
    api       = aws_codedeploy_app.api.name
    dashboard = aws_codedeploy_app.dashboard.name
  }
  description = "CodeDeploy application names by blue/green service."
}

output "codedeploy_deployment_group_names" {
  value = {
    api       = aws_codedeploy_deployment_group.api.deployment_group_name
    dashboard = aws_codedeploy_deployment_group.dashboard.deployment_group_name
  }
  description = "CodeDeploy deployment group names by blue/green service."
}
