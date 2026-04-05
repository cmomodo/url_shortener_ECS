resource "aws_ssm_parameter" "database_url" {
  name  = "/url-shortener/database_url"
  type  = "SecureString"
  value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.url_shortener.endpoint}/${var.db_name}"
}

#worker ssm parameter
resource "aws_ssm_parameter" "sqs_queue_url" {
  name  = "/url-shortener/sqs_queue_url"
  type  = "String"
  value = aws_sqs_queue.terraform_queue.url
}

#redis parameter
resource "aws_ssm_parameter" "redis_url" {
  name  = "/url-shortener/redis_url"
  type  = "String"
  value = "redis://${aws_elasticache_cluster.url_shortener.cache_nodes[0].address}:6379"
}
