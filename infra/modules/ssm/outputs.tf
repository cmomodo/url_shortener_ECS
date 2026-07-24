output "database_url_parameter_arn" {
  value       = aws_ssm_parameter.database_url.arn
  description = "SSM parameter ARN for DATABASE_URL."
}

output "sqs_queue_url_parameter_arn" {
  value       = aws_ssm_parameter.sqs_queue_url.arn
  description = "SSM parameter ARN for SQS_QUEUE_URL."
}

output "redis_url_parameter_arn" {
  value       = aws_ssm_parameter.redis_url.arn
  description = "SSM parameter ARN for REDIS_URL."
}
