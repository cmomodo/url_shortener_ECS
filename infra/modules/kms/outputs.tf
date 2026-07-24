output "key_id" {
  value       = aws_kms_key.app.id
  description = "ID of the application CMK"
}

output "key_arn" {
  value       = aws_kms_key.app.arn
  description = "ARN of the application CMK"
}
