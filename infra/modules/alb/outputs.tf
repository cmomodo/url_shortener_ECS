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

output "api_target_group_arn" {
  value       = aws_lb_target_group.api.arn
  description = "ARN of the API blue target group."
}

output "api_green_target_group_arn" {
  value       = aws_lb_target_group.api_green.arn
  description = "ARN of the API green target group."
}

output "dashboard_target_group_arn" {
  value       = aws_lb_target_group.dashboard.arn
  description = "ARN of the dashboard blue target group."
}

output "dashboard_green_target_group_arn" {
  value       = aws_lb_target_group.dashboard_green.arn
  description = "ARN of the dashboard green target group."
}

output "api_target_group_name" {
  value       = aws_lb_target_group.api.name
  description = "Name of the API blue target group."
}

output "api_green_target_group_name" {
  value       = aws_lb_target_group.api_green.name
  description = "Name of the API green target group."
}

output "dashboard_target_group_name" {
  value       = aws_lb_target_group.dashboard.name
  description = "Name of the dashboard blue target group."
}

output "dashboard_green_target_group_name" {
  value       = aws_lb_target_group.dashboard_green.name
  description = "Name of the dashboard green target group."
}

output "https_listener_arn" {
  value       = aws_lb_listener.https.arn
  description = "ARN of the HTTPS production listener."
}

output "api_test_listener_arn" {
  value       = aws_lb_listener.api_test.arn
  description = "ARN of the API test traffic listener."
}

output "dashboard_test_listener_arn" {
  value       = aws_lb_listener.dashboard_test.arn
  description = "ARN of the dashboard test traffic listener."
}
