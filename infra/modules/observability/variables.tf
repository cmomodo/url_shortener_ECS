variable "kms_key_arn" {
  type        = string
  description = "ARN of the CMK used for WAF log bucket and Firehose encryption"
}

variable "alb_arn" {
  type        = string
  description = "ARN of the ALB the regional WAF Web ACL is associated with"
}

variable "cloudfront_origin_verify_secret" {
  type        = string
  description = "Secret header value required on requests from CloudFront"
  sensitive   = true
}
