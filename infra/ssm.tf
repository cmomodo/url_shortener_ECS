resource "aws_ssm_parameter" "database_url" {
  name  = "/url-shortener/database_url"
  type  = "SecureString"
  value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.default.endpoint}/${var.db_name}"
}

resource "aws_ssm_parameter" "redis_url" {
  name  = "/url-shortener/redis_url"
  type  = "SecureString"
  value = "placeholder"   # update once ElastiCache is provisioned

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "sqs_queue_url" {
  name  = "/url-shortener/sqs_queue_url"
  type  = "String"
  value = aws_sqs_queue.terraform_queue.url
}
