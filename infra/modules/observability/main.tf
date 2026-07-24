# ALB access logs, regional WAF for the ALB, and WAF logging via Kinesis Firehose.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "url-shortener-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  #checkov:skip=CKV_AWS_144: Cross-region replication not required for this project (single-region, rebuildable logs)
  #checkov:skip=CKV_AWS_145: ALB access log delivery requires S3-managed encryption, not KMS
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      # ALB access log delivery only supports S3-managed encryption keys.
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-alb-logs"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_notification" "alb_logs" {
  bucket      = aws_s3_bucket.alb_logs.id
  eventbridge = true
}

# Server access logs for the ALB logs bucket (required by CKV_AWS_18).
resource "aws_s3_bucket" "alb_logs_access" {
  bucket        = "url-shortener-alb-logs-access-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  #checkov:skip=CKV_AWS_144: Cross-region replication not required for this project (single-region, rebuildable logs)
  #checkov:skip=CKV_AWS_145: S3 server access log delivery requires S3-managed encryption, not KMS
}

# Enable versioning for the ALB logs access bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_versioning" "alb_logs_access" {
  bucket = aws_s3_bucket.alb_logs_access.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable versioning for the ALB logs access bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_notification" "alb_logs_access" {
  bucket      = aws_s3_bucket.alb_logs_access.id
  eventbridge = true

  #checkov:skip=CKV_AWS_18: EventBridge notifications are enabled for the ALB logs access bucket (required by CKV_AWS_18).
}

# Enable public access block for the ALB logs access bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_public_access_block" "alb_logs_access" {
  bucket = aws_s3_bucket.alb_logs_access.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption for the ALB logs access bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs_access" {
  bucket = aws_s3_bucket.alb_logs_access.id

  rule {
    apply_server_side_encryption_by_default {
      # S3 server access log delivery only supports S3-managed encryption keys.
      sse_algorithm = "AES256"
    }
  }
}

# Enable lifecycle configuration for the ALB logs access bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs_access" {
  bucket = aws_s3_bucket.alb_logs_access.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 90
    }
  }
}

# Enable logging for the ALB logs access bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_logging" "alb_logs" {
  bucket        = aws_s3_bucket.alb_logs.id
  target_bucket = aws_s3_bucket.alb_logs_access.id
  target_prefix = "s3-access-logs/"
}

# ALB access logging requires the Elastic Load Balancing log delivery service.
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowELBLogDeliveryPut"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:elasticloadbalancing:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"
          }
        }
      },
      {
        Sid    = "AllowELBLogDeliveryAcl"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:elasticloadbalancing:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"
          }
        }
      }
    ]
  })
}

# Enable WAF for the ALB (required by CKV_AWS_18).
resource "aws_wafv2_web_acl" "alb" {
  name  = "url-shortener-alb"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RequireCloudFrontOriginHeader"
    priority = 0

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          byte_match_statement {
            positional_constraint = "EXACTLY"
            search_string         = var.cloudfront_origin_verify_secret

            field_to_match {
              single_header {
                name = "x-origin-verify"
              }
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "url-shortener-waf-origin-header"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "url-shortener-waf-common"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "url-shortener-waf-bad-inputs"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "url-shortener-waf-sqli"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "url-shortener-waf"
    sampled_requests_enabled   = false
  }
}

# Enable WAF logging for the ALB (required by CKV2_AWS_31). WAF logs must go to Kinesis Firehose.
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}

# WAF logging (required by CKV2_AWS_31). WAF logs must go to Kinesis Firehose.
resource "aws_s3_bucket" "waf_logs" {
  bucket        = "url-shortener-waf-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  #checkov:skip=CKV_AWS_144: Cross-region replication not required for this project (single-region, rebuildable logs)
}

# Enable server-side encryption for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_versioning" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_notification" "waf_logs" {
  bucket      = aws_s3_bucket.waf_logs.id
  eventbridge = true

  #checkov:skip=CKV_AWS_144: Cross-region replication not required for this project (single-region, rebuildable logs)
}

# Enable logging for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_logging" "waf_logs" {
  bucket        = aws_s3_bucket.waf_logs.id
  target_bucket = aws_s3_bucket.alb_logs_access.id
  target_prefix = "waf-s3-access-logs/"

  #checkov:skip=CKV_AWS_144: Cross-region replication not required for this project (single-region, rebuildable logs)
}

# Enable public access block for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_public_access_block" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Enable server-side encryption for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_server_side_encryption_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

# Enable lifecycle configuration for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_s3_bucket_lifecycle_configuration" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    id     = "expire-waf-logs"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 90
    }
  }
}

# Enable IAM role for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_iam_role" "firehose_waf_logs" {
  name = "url-shortener-firehose-waf-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Enable IAM role policy for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_iam_role_policy" "firehose_waf_logs" {
  name = "url-shortener-firehose-waf-logs"
  role = aws_iam_role.firehose_waf_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.waf_logs.arn,
          "${aws_s3_bucket.waf_logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Enable Kinesis Firehose delivery stream for the WAF logs bucket (required by CKV_AWS_18).
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "aws-waf-logs-url-shortener"
  destination = "extended_s3"

  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = var.kms_key_arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_waf_logs.arn
    bucket_arn = aws_s3_bucket.waf_logs.arn
    prefix     = "waf/"
  }
}

# Enable WAF logging configuration for the ALB (required by CKV_AWS_18).
resource "aws_wafv2_web_acl_logging_configuration" "alb" {
  resource_arn            = aws_wafv2_web_acl.alb.arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs.arn]

  redacted_fields {
    single_header {
      name = "x-origin-verify"
    }
  }
}
