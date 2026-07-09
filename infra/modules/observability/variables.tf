variable "kms_key_arn" {
  type        = string
  description = "ARN of the CMK used for WAF log bucket and Firehose encryption"
}

variable "alb_arn" {
  type        = string
  description = "ARN of the ALB the regional WAF Web ACL is associated with"
}
