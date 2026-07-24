data "aws_caller_identity" "current" {}

data "aws_acm_certificate" "cert" {
  domain      = "ceedev.co.uk"
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

#cloudfront distribution for alb
resource "aws_cloudfront_distribution" "alb_distribution" {
  # Standard logging requires the log bucket to allow ACLs (ownership != bucket-owner-enforced).
  depends_on = [aws_s3_bucket_acl.cloudfront_logs]

  #checkov:skip=CKV2_AWS_47: AWSManagedRulesKnownBadInputsRuleSet (Log4JRCE) is configured in aws_wafv2_web_acl.cloudfront; Checkov cannot cross-reference the WAF rules statically
  #checkov:skip=CKV2_AWS_46: Origin is an ALB, not an S3 bucket; Origin Access Control is not applicable to ALB origins
  #checkov:skip=CKV_AWS_310: Single-origin dev distribution; no secondary origin exists for failover
  #accept traffic from these domains
  aliases = var.aliases

  origin {
    # CloudFront verifies the origin TLS cert against this hostname. The ALB
    # serves the *.ceedev.co.uk ACM cert, so we point at origin.ceedev.co.uk
    # (a Route 53 alias to the ALB) rather than the ALB's *.elb.amazonaws.com
    # name, which the cert doesn't cover.
    domain_name = var.domain_name
    origin_id   = "alb-origin"

    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_verify_secret
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled = true
  # CloudFront rewrites a request for "/" to "/<default_root_object>" before
  # forwarding to the origin. The FastAPI app exposes the UI at /ui (see
  # app/src/main.py), so route apex traffic there. Anything else (e.g. /summary,
  # /healthz, short-codes) is unaffected.
  default_root_object = "ui"

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  default_cache_behavior {
    target_origin_id           = "alb-origin"
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }
  }

  logging_config {
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["GB"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Response headers policy with security headers — fixes CKV2_AWS_32
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "url-shortener-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }

    content_type_options {
      override = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

#bucket logs from checkov 
resource "aws_s3_bucket" "cloudfront_logs" {
  #checkov:skip=CKV_AWS_18: This bucket is itself a log destination; logging it to another bucket is circular
  #checkov:skip=CKV2_AWS_62: Log bucket does not require event notifications
  #checkov:skip=CKV_AWS_144: Cross-region replication not required for a disposable log bucket in a dev environment
  #checkov:skip=CKV_AWS_21: Versioning not needed for append-only CloudFront access logs
  #checkov:skip=CKV_AWS_145: CloudFront log delivery cannot write to KMS-encrypted buckets; SSE-S3 is the only supported encryption for CloudFront logging destinations
  bucket        = "url-shortener-cloudfront-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# CloudFront standard logging uses canned ACLs. Object Ownership must NOT be "Bucket owner
# enforced" (that disables all ACLs). BucketOwnerPreferred keeps ACLs enabled for the bucket.
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  #checkov:skip=CKV2_AWS_65: CloudFront Standard Logging requires ACLs to be enabled (BucketOwnerPreferred) to deliver logs.
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

# Block all public access on the log bucket — fixes CKV2_AWS_6
resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  depends_on = [
    aws_s3_bucket_ownership_controls.cloudfront_logs,
    aws_s3_bucket_acl.cloudfront_logs,
  ]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to manage log retention costs — fixes CKV2_AWS_61
resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  depends_on = [aws_s3_bucket_acl.cloudfront_logs]

  rule {
    id     = "expire-logs"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

#waf suggestion from checkov
resource "aws_wafv2_web_acl" "cloudfront" {
  name  = "url-shortener-cloudfront"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitGlobal"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitGlobal"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitShorten"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = var.shorten_rate_limit
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300

        scope_down_statement {
          and_statement {
            statement {
              byte_match_statement {
                positional_constraint = "EXACTLY"
                search_string         = "/shorten"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }

            statement {
              byte_match_statement {
                positional_constraint = "EXACTLY"
                search_string         = "POST"

                field_to_match {
                  method {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitShorten"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "BlockUnsupportedMethods"
    priority = 4

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          or_statement {
            dynamic "statement" {
              for_each = toset(["GET", "HEAD", "OPTIONS", "POST"])

              content {
                byte_match_statement {
                  positional_constraint = "EXACTLY"
                  search_string         = statement.value

                  field_to_match {
                    method {}
                  }

                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockUnsupportedMethods"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "BlockInvalidShortenRequests"
    priority = 5

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            positional_constraint = "EXACTLY"
            search_string         = "/shorten"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }

        statement {
          or_statement {
            statement {
              not_statement {
                statement {
                  byte_match_statement {
                    positional_constraint = "EXACTLY"
                    search_string         = "POST"

                    field_to_match {
                      method {}
                    }

                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }

            statement {
              not_statement {
                statement {
                  byte_match_statement {
                    positional_constraint = "STARTS_WITH"
                    search_string         = "application/json"

                    field_to_match {
                      single_header {
                        name = "content-type"
                      }
                    }

                    text_transformation {
                      priority = 0
                      type     = "LOWERCASE"
                    }
                  }
                }
              }
            }

            statement {
              size_constraint_statement {
                comparison_operator = "GT"
                size                = 4096

                field_to_match {
                  body {}
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockInvalidShortenRequests"
      sampled_requests_enabled   = true
    }
  }

  # Blocks Log4Shell (CVE-2021-44228) and other known-bad inputs — fixes CKV_AWS_192 / CKV2_AWS_47
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 6

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
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # General web exploit protection (SQLi, XSS, etc.) — fixes CKV_AWS_175
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 7

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
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 8

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
      metric_name                = "AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "url-shortener-cf-waf"
    sampled_requests_enabled   = true
  }
}

# WAF log group — name must start with aws-waf-logs- (AWS requirement) — fixes CKV2_AWS_31
resource "aws_cloudwatch_log_group" "waf" {
  #checkov:skip=CKV_AWS_338: Testing environment - 90 day retention is sufficient
  #checkov:skip=CKV_AWS_158: Testing environment - KMS encryption not required, adds unnecessary cost
  name              = "aws-waf-logs-url-shortener"
  retention_in_days = 1
}

resource "aws_wafv2_web_acl_logging_configuration" "cloudfront" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront.arn
}

output "domain_name" {
  value = aws_cloudfront_distribution.alb_distribution.domain_name
}

output "hosted_zone_id" {
  value = aws_cloudfront_distribution.alb_distribution.hosted_zone_id
}
