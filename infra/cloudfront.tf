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
    target_origin_id       = "alb-origin"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
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

#bucket logs from checkov 
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket        = "url-shortener-cloudfront-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

#waf suggestion from checkov
resource "aws_wafv2_web_acl" "cloudfront" {
  name  = "url-shortener-cloudfront"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "url-shortener-cf-waf"
    sampled_requests_enabled   = true
  }
}