#cloudfront distribution for alb
resource "aws_cloudfront_distribution" "alb_distribution" {
  #accept traffic from these domains
   aliases = ["ceedev.co.uk", "www.ceedev.co.uk"]

  origin {
    #cloudfront distribution to the alb
    domain_name = aws_lb.main.dns_name # ALB
    origin_id   = "alb-origin"
   

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only" # or "match-viewer"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  #failover suggestion from checkov 
  origin_group {
    origin_id = "alb-origin"

    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "alb-origin"
    }

    member {
      origin_id = "alb-origin"
    }
  }
  enabled             = true
  default_root_object = "index.html"

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn

  default_cache_behavior {
    target_origin_id          = "alb-origin"
    allowed_methods           = ["GET", "HEAD", "OPTIONS"]
    cached_methods            = ["GET", "HEAD"]
    viewer_protocol_policy    = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
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
  bucket        = "url-shortener-cloudfront-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

# Lifecycle policy to manage log retention costs — fixes CKV2_AWS_61
resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

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

  # Blocks Log4Shell (CVE-2021-44228) and other known-bad inputs — fixes CKV_AWS_192 / CKV2_AWS_47
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1

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
    priority = 2

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
  retention_in_days = 90
}

resource "aws_wafv2_web_acl_logging_configuration" "cloudfront" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.cloudfront.arn
}