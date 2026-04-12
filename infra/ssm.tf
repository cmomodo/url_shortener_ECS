resource "aws_ssm_parameter" "database_url" {
  name   = "/url-shortener/database_url"
  type   = "SecureString"
  key_id = aws_kms_key.app.id
  value  = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.url_shortener.endpoint}/${var.db_name}"
}

resource "aws_ssm_parameter" "sqs_queue_url" {
  name   = "/url-shortener/sqs_queue_url"
  type   = "SecureString"
  key_id = aws_kms_key.app.id
  value  = aws_sqs_queue.terraform_queue.url
}

resource "aws_ssm_parameter" "redis_url" {
  name   = "/url-shortener/redis_url"
  type   = "SecureString"
  key_id = aws_kms_key.app.id
  value  = "redis://${aws_elasticache_cluster.url_shortener.cache_nodes[0].address}:6379"
}
