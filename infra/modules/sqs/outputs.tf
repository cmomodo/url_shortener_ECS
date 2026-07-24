output "queue_arn" {
  value       = aws_sqs_queue.terraform_queue.arn
  description = "ARN of the primary click-events queue"
}

output "queue_url" {
  value       = aws_sqs_queue.terraform_queue.url
  description = "URL of the primary click-events queue"
}

output "dead_letter_queue_arn" {
  value       = aws_sqs_queue.secondary_queue_deadletter.arn
  description = "ARN of the dead-letter queue"
}
