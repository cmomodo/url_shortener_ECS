we will be using kms to encrypt the sensitive data in the s3 bucket and the database.

- SSM SecureString parameters encrypt secrets (database URL, Redis URL). The SQS queue URL is a non-sensitive `String` parameter to avoid KMS decrypt on every task start.
- ElastiCache Redis uses in-transit TLS (`rediss://`), encryption at rest, and an auth token. See [elasticache.md](./elasticache.md).
- RDS encrypts database storage and Performance Insights with it.
- SQS encrypts the primary queue and dead-letter queue messages.
- CloudWatch Logs encrypts ECS log groups.
- S3 buckets for ALB/logging use SSE-KMS with this key.
- ECS task roles are granted KMS permissions so containers can read encrypted SSM parameters and work with encrypted SQS messages.

It's tightly coupled, with automatic key rotation enabled. No custom `rotation_period_in_days` is set, so AWS rotates the backing key material on its default annual (365-day) schedule. The key ID, ARN, and alias stay the same across rotations.

## SQS access control

The primary queue is protected by two complementary layers:

- **Identity-based (IAM) policies** define what each role is allowed to do: the API task role can only `SendMessage`, and the worker task role can only `ReceiveMessage` / `DeleteMessage` / `ChangeMessageVisibility`.
- **A resource-based policy on the queue** defines who the queue is willing to be accessed by. It explicitly allows only those two roles and adds explicit `Deny` statements that block (a) any principal whose ARN is not the API or worker role (`aws:PrincipalArn` guardrail), and (b) any request not made over TLS (`aws:SecureTransport`).

Because an explicit `Deny` overrides every `Allow` — IAM or resource-based — the queue enforces its own trust boundary regardless of what permissions exist elsewhere in the account.

### The dashboard has no access

The dashboard service is intentionally locked out of SQS:

- Its ECS task definition sets only an `execution_role_arn` and **no `task_role_arn`**, so the dashboard container has no runtime IAM permissions for SQS (or any other AWS API).
- Even if a permission were granted by mistake, the queue's resource policy `Deny` would still block it, since the dashboard role is not in the allowed `aws:PrincipalArn` list.

Only the API (producer) and worker (consumer) can interact with the queue.
