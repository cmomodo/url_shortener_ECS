data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

# route53 record via module
module "route53" {
  source = "./modules/route53"

  hosted_zone_id         = data.aws_route53_zone.main.zone_id
  record_name            = "ceedev.co.uk"
  alias_name             = aws_cloudfront_distribution.alb_distribution.domain_name
  alias_zone_id          = aws_cloudfront_distribution.alb_distribution.hosted_zone_id
  evaluate_target_health = true
}
