resource "aws_elasticache_parameter_group" "url_shortener" {
  name   = "url-shortener-redis7"
  family = "redis7"
}

resource "aws_elasticache_subnet_group" "url_shortener" {
  name       = var.subnet_group_name
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "url_shortener" {
  #checkov:skip=CKV2_AWS_50: Dev environment keeps a single node (no Multi-AZ failover) to reduce baseline cost.
  replication_group_id = var.replication_group_id
  description          = "URL shortener Redis (TLS + auth)"
  engine               = var.engine
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = var.port
  parameter_group_name = aws_elasticache_parameter_group.url_shortener.name
  subnet_group_name    = aws_elasticache_subnet_group.url_shortener.name
  security_group_ids   = var.security_group_ids

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_id
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"

  auth_token                 = var.auth_token
  auth_token_update_strategy = "SET"

  snapshot_retention_limit = 1
  snapshot_window          = var.snapshot_window
}
