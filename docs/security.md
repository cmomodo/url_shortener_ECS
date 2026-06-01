we will be using kms to encrypt the sensitive data in the s3 bucket and the database.

- SSM SecureString parameters encrypt secrets (database URL, Redis URL). The SQS queue URL is a non-sensitive `String` parameter to avoid KMS decrypt on every task start.
- ElastiCache Redis uses in-transit TLS (`rediss://`), encryption at rest, and an auth token. See [elasticache.md](./elasticache.md).
- RDS encrypts database storage and Performance Insights with it.
- SQS encrypts the primary queue and dead-letter queue messages.
- CloudWatch Logs encrypts ECS log groups.
- S3 buckets for ALB/logging use SSE-KMS with this key.
- ECS task roles are granted KMS permissions so containers can read encrypted SSM parameters and work with encrypted SQS messages.

It's tightly coupled, with automatic key rotation enabled. No custom `rotation_period_in_days` is set, so AWS rotates the backing key material on its default annual (365-day) schedule. The key ID, ARN, and alias stay the same across rotations.
