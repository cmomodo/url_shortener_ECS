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
  description = "Max requests per client IP in a 5-minute window before WAF blocks (minimum 100)"
  default     = 2000
}