output "alb_logs_bucket_id" {
  value       = aws_s3_bucket.alb_logs.id
  description = "ALB access-logs bucket name (ready for log delivery once the bucket policy is applied)"

  # ALB creation with access logging enabled fails unless the ELB log-delivery
  # bucket policy is already in place, so consumers must wait for it.
  depends_on = [aws_s3_bucket_policy.alb_logs]
}
