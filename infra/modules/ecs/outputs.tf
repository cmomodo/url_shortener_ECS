output "alb_dns" {
  value       = aws_lb.main.dns_name
  description = "ALB DNS name."
  sensitive   = true
}

output "alb_arn" {
  value       = aws_lb.main.arn
  description = "ARN of the application load balancer."
}

output "alb_zone_id" {
  value       = aws_lb.main.zone_id
  description = "Route 53 hosted zone ID of the application load balancer."
}

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
    worker    = aws_codedeploy_app.worker.name
  }
  description = "CodeDeploy application names by service."
}

output "codedeploy_deployment_group_names" {
  value = {
    api       = aws_codedeploy_deployment_group.api.deployment_group_name
    dashboard = aws_codedeploy_deployment_group.dashboard.deployment_group_name
    worker    = aws_codedeploy_deployment_group.worker.deployment_group_name
  }
  description = "CodeDeploy deployment group names by service."
}
