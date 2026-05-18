we will be using kms to encrypt the sensitive data in the s3 bucket and the database.

- SSM SecureString parameters encrypt app secrets/config like database URL, SQS URL, and Redis URL.
- RDS encrypts database storage and Performance Insights with it.
- SQS encrypts the primary queue and dead-letter queue messages.
- CloudWatch Logs encrypts ECS log groups.
- S3 buckets for ALB/logging use SSE-KMS with this key.
- ECS task roles are granted KMS permissions so containers can read encrypted SSM parameters and work with encrypted SQS messages.

its tightly coupled and its rotated every 10 days.
