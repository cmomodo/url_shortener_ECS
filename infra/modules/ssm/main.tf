resource "aws_ssm_parameter" "database_url" {
  name   = "/url-shortener/database_url"
  type   = "SecureString"
  key_id = var.kms_key_id

  value_wo = "postgresql://${var.db_username}:${var.db_password}@${var.db_endpoint}/${var.db_name}"
  # Bump with db_password_wo_version when rotating the DB password.
  value_wo_version = var.db_password_wo_version
}

resource "aws_ssm_parameter" "sqs_queue_url" {
  name   = "/url-shortener/sqs_queue_url"
  type   = "SecureString"
  key_id = var.kms_key_id
  value  = var.sqs_queue_url
}

resource "aws_ssm_parameter" "redis_url" {
  name   = "/url-shortener/redis_url"
  type   = "SecureString"
  key_id = var.kms_key_id
  value  = "rediss://:${urlencode(var.redis_auth_token)}@${var.redis_endpoint}:${var.redis_port}"
}
