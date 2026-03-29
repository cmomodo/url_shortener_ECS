resource "aws_ssm_parameter" "database_url" {
  name  = "/url-shortener/database_url"
  type  = "SecureString"
  value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.url_shortener.endpoint}/${var.db_name}"
}
