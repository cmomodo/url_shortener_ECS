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
