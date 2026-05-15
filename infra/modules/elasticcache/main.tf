#redis instance.
resource "aws_elasticache_cluster" "url_shortener" {
  cluster_id               = var.cluster_id
  engine                   = var.engine
  engine_version           = var.engine_version
  node_type                = var.node_type
  num_cache_nodes          = var.num_cache_nodes
  parameter_group_name     = var.parameter_group_name
  port                     = var.port
  subnet_group_name        = aws_elasticache_subnet_group.url_shortener.name
  security_group_ids       = var.security_group_ids
  snapshot_retention_limit = 1
  snapshot_window          = var.snapshot_window
}

#placing it inside the private subnet.
resource "aws_elasticache_subnet_group" "url_shortener" {
  name       = var.subnet_group_name
  subnet_ids = var.private_subnet_ids
}

output "cache_node_address" {
  value = aws_elasticache_cluster.url_shortener.cache_nodes[0].address
}

