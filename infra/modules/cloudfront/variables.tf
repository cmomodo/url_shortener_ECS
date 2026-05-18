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