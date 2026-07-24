
output "primary_endpoint_address" {
  value = aws_elasticache_replication_group.url_shortener.primary_endpoint_address
}

output "port" {
  value = var.port
}

output "auth_token" {
  value       = random_password.redis_auth.result
  description = "Redis AUTH token (16–128 chars; required when transit encryption is enabled)"
  sensitive   = true
}
