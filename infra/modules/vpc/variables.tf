#alb_allowed_ingress_cidrs for the vpc
variable "alb_allowed_ingress_cidrs" {
  type        = list(string)
  description = "ALB allowed ingress CIDRs"
  default     = ["0.0.0.0/0"]
}

#private_subnet_cidrs for the vpc
variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs"
  default     = ["172.31.96.0/24", "172.31.97.0/24"]
}

#identifier for the vpc
variable "identifier" {
  type        = string
  description = "Identifier for the vpc"
  default     = "url-shortener-vpc"
}