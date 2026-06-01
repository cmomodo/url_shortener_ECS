resource "aws_ssm_parameter" "database_url" {
  name   = "/url-shortener/database_url"
  type   = "SecureString"
  key_id = aws_kms_key.app.id

  value_wo = "postgresql://${var.db_username}:${ephemeral.random_password.db_master.result}@${aws_db_instance.url_shortener.endpoint}/${var.db_name}"
  # Bump with db_password_wo_version when rotating the DB password.
  value_wo_version = var.db_password_wo_version
}

resource "aws_ssm_parameter" "sqs_queue_url" {
  name  = "/url-shortener/sqs_queue_url"
  type  = "String"
  value = aws_sqs_queue.terraform_queue.url
}

resource "aws_ssm_parameter" "redis_url" {
  name   = "/url-shortener/redis_url"
  type   = "SecureString"
  key_id = aws_kms_key.app.id
  value  = "rediss://:${urlencode(random_password.redis_auth.result)}@${module.elasticcache.primary_endpoint_address}:${module.elasticcache.port}"
}
