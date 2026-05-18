data "aws_route53_zone" "main" {
  zone_id = var.hosted_zone_id
}

# route53 record via module
module "route53" {
  source = "./modules/route53"

  hosted_zone_id = data.aws_route53_zone.main.zone_id
  record_name    = "ceedev.co.uk"
  alias_name     = module.cloudfront.domain_name
  alias_zone_id  = module.cloudfront.hosted_zone_id
  # Route 53 ignores target health checks on CloudFront alias targets.
  evaluate_target_health = false
}

# www record: www.ceedev.co.uk -> CloudFront
module "route53_www" {
  source = "./modules/route53"

  hosted_zone_id         = data.aws_route53_zone.main.zone_id
  record_name            = "www.ceedev.co.uk"
  alias_name             = module.cloudfront.domain_name
  alias_zone_id          = module.cloudfront.hosted_zone_id
  evaluate_target_health = false
}


module "route53_origin" {
  source = "./modules/route53"

  hosted_zone_id         = data.aws_route53_zone.main.zone_id
  record_name            = "origin.ceedev.co.uk"
  alias_name             = module.ecs.alb_dns
  alias_zone_id          = module.ecs.alb_zone_id
  evaluate_target_health = false
}
