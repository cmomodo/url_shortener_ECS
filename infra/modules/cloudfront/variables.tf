#aliases for the cloudfront distribution
variable "aliases" {
  type        = list(string)
  description = "Aliases for the cloudfront distribution"
  default     = ["ceedev.co.uk", "www.ceedev.co.uk"]
}

#domain name for the cloudfront distribution
variable "domain_name" {
  type        = string
  description = "Domain name for the cloudfront distribution"
  default     = "origin.ceedev.co.uk"
}

# WAF rate limit (requests per 5-minute window per client IP)
variable "waf_rate_limit" {
  type        = number
  description = "Max requests per client IP in a 5-minute window before WAF blocks"
  default     = 2000
}

variable "shorten_rate_limit" {
  type        = number
  description = "Max POST /shorten requests per client IP in a 5-minute window"
  default     = 50
}

variable "origin_verify_secret" {
  type        = string
  description = "Secret header value CloudFront adds to requests sent to the ALB"
  sensitive   = true
}
