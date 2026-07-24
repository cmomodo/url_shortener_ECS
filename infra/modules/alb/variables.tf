variable "vpc_id" {
  type        = string
  description = "VPC ID for ALB target groups."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB."
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID for the ALB."
}

variable "alb_logs_bucket_id" {
  type        = string
  description = "S3 bucket ID for ALB access logs."
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the HTTPS listener."
}
