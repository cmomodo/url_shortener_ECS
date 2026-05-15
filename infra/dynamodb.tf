
# --- urls -------------------------------------------------------------------
# Stores short-code -> long-url mappings plus a click counter.
# Access pattern: GetItem / PutItem / UpdateItem ADD on `clicks`.
resource "aws_dynamodb_table" "urls" {
  #checkov:skip=CKV_AWS_119: SSE-KMS with CMK is configured below
  #checkov:skip=CKV_AWS_28: PITR enabled below
  name         = "url-shortener-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  deletion_protection_enabled = false

  tags = {
    Name = "url-shortener-urls"
  }
}

# --- click_events -----------------------------------------------------------
# One item per redirect. Worker writes here from SQS.
#
# Primary key:
#   PK short_code   - all events for a given short URL live in one partition
#   SK event_id     - "<clicked_at_iso>#<uuid>" so events sort chronologically
#                     within a short_code and are unique
#
# GSI "ByDate": supports the dashboard "/recent across all codes" query.
#   PK event_date (YYYY-MM-DD) - bounded fan-out (1 partition/day)
#   SK clicked_at (ISO 8601)   - reverse-scan to get latest N
resource "aws_dynamodb_table" "click_events" {
  #checkov:skip=CKV_AWS_119: SSE-KMS with CMK is configured below
  #checkov:skip=CKV_AWS_28: PITR enabled below
  name         = "url-shortener-click-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"
  range_key    = "event_id"

  attribute {
    name = "short_code"
    type = "S"
  }
  attribute {
    name = "event_id"
    type = "S"
  }
  attribute {
    name = "event_date"
    type = "S"
  }
  attribute {
    name = "clicked_at"
    type = "S"
  }

  global_secondary_index {
    name            = "ByDate"
    projection_type = "ALL"
    key_schema {
      attribute_name = "event_date"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "clicked_at"
      key_type       = "RANGE"
    }
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  deletion_protection_enabled = false

  tags = {
    Name = "url-shortener-click-events"
  }
}

# --- click_stats_hourly -----------------------------------------------------
# Pre-aggregated per (short_code, hour) counters. Worker upserts via:
#   UpdateExpression: "ADD clicks :one"
#
# Primary key:
#   PK short_code
#   SK hour - ISO 8601 truncated to the hour, e.g. "2026-05-10T10:00:00Z"
resource "aws_dynamodb_table" "click_stats_hourly" {
  #checkov:skip=CKV_AWS_119: SSE-KMS with CMK is configured below
  #checkov:skip=CKV_AWS_28: PITR enabled below
  name         = "url-shortener-click-stats-hourly"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"
  range_key    = "hour"

  attribute {
    name = "short_code"
    type = "S"
  }
  attribute {
    name = "hour"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  deletion_protection_enabled = false

  tags = {
    Name = "url-shortener-click-stats-hourly"
  }
}

# --- Outputs ----------------------------------------------------------------
# Exposed so future ecs.tf wiring can pass these as TABLE_* env vars.
output "ddb_table_urls" {
  value       = aws_dynamodb_table.urls.name
  description = "DynamoDB table name for url mappings (set as TABLE_NAME on the API)"
}

output "ddb_table_click_events" {
  value       = aws_dynamodb_table.click_events.name
  description = "DynamoDB table name for raw click events"
}

output "ddb_table_click_stats_hourly" {
  value       = aws_dynamodb_table.click_stats_hourly.name
  description = "DynamoDB table name for hourly click aggregations"
}
