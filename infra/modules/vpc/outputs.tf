output "vpc_id" {
  value       = data.aws_vpc.main.id
  description = "Default VPC ID used by this stack"
}

output "private_subnet_ids" {
  value       = aws_subnet.private_blocks[*].id
  description = "Private subnets for RDS, ElastiCache, VPC endpoints, and ECS tasks"
}

output "default_public_subnet_ids" {
  value       = data.aws_subnets.default.ids
  description = "Default public subnets in the VPC (ALB placement)"
}

output "private_route_table_id" {
  value       = aws_route_table.private.id
  description = "Route table associated with private subnets"
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}

output "dashboard_tasks_security_group_id" {
  value = aws_security_group.dashboard_tasks.id
}

output "worker_tasks_security_group_id" {
  value = aws_security_group.worker_tasks.id
}

output "vpce_interface_security_group_id" {
  value = aws_security_group.vpce_interface.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds_service.id
}
