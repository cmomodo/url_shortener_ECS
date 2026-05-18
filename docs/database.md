# Database choice

The active AWS deployment uses **RDS PostgreSQL**.

PostgreSQL is the best fit for the current codebase because all three services can use one shared relational schema:

- `api` writes URL mappings to `urls` and increments the redirect counter.
- `worker` consumes SQS click events and writes `click_events` plus `click_stats_hourly`.
- `dashboard` reads those same tables for summary, recent-click, top-URL, and per-URL analytics endpoints.

The ECS task definitions pass `DATABASE_URL` to the API, worker, and dashboard. In `app/src/db.py`, `DATABASE_URL` also takes precedence over `TABLE_NAME`, so the deployed API uses PostgreSQL even though the Python abstraction still has a DynamoDB backend for experiments.

## Alternatives considered

### DynamoDB

DynamoDB fits the redirect lookup path well because URL resolution is a simple key-value read by short code, and click increments can be handled with atomic updates. It is not the active deployment choice because the analytics side of the app currently depends on SQL queries and PostgreSQL-specific upserts.

Moving fully to DynamoDB would require a separate implementation pass:

- Model URL mappings, raw click events, hourly aggregates, and top URLs as explicit DynamoDB access patterns.
- Rewrite the Go worker to write DynamoDB items instead of PostgreSQL rows.
- Rewrite the dashboard endpoints to use DynamoDB `Query`/GSI access instead of SQL.
- Add IAM permissions and Terraform tables only after the application code is ready to use them.

### Aurora PostgreSQL

Aurora PostgreSQL would be a good upgrade path for a production deployment that needs higher availability, replicas, or easier database scaling. For this dev-sized project, single-AZ RDS PostgreSQL is simpler and cheaper.

### Aurora DSQL

Aurora DSQL is compelling for serverless distributed SQL and active-active multi-region workloads. This application does not currently need distributed writes or multi-region database semantics, so DSQL adds service novelty and migration risk without improving the current deployment.
