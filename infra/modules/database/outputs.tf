output "endpoint" {
  value       = aws_db_instance.url_shortener.endpoint
  description = "RDS instance endpoint (host:port)"
}

# Ephemeral: never persisted to state; consumed by write-only arguments only.
output "master_password" {
  value     = ephemeral.random_password.db_master.result
  ephemeral = true
}
