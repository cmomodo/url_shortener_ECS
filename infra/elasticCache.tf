resource "aws_elasticache_cluster" "url_shortener" {
  cluster_id           = "cluster-url"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.url_shortener.name
  security_group_ids   = [aws_security_group.ecs_tasks.id]
}

resource "aws_elasticache_subnet_group" "url_shortener" {
  name       = "url-shortener-cache"
  subnet_ids = aws_subnet.private_blocks[*].id
}
