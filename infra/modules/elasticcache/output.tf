
output "primary_endpoint_address" {
  value = aws_elasticache_replication_group.url_shortener.primary_endpoint_address
}

output "port" {
  value = var.port
}
