# Shared lookups for resources managed outside this stack.

# Issued ACM certificate for the domain (used by the ECS ALB HTTPS listener).
data "aws_acm_certificate" "cert" {
  domain      = "ceedev.co.uk"
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

# ECR repositories are created by the separate infra/ecr-chicken bootstrap stack.
data "aws_ecr_repository" "api" {
  name = "url-shortener/api"
}

data "aws_ecr_repository" "dashboard" {
  name = "url-shortener/dashboard"
}

data "aws_ecr_repository" "worker" {
  name = "url-shortener/worker"
}

data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}
