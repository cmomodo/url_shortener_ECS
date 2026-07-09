# Root orchestration: every resource lives in a module under ./modules;
# this file only wires the modules together.

# --- Networking ---
module "vpc" {
  source = "./modules/vpc"
}

module "endpoints" {
  source = "./modules/endpoints"

  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  security_group_id      = module.vpc.vpce_interface_security_group_id
  private_route_table_id = module.vpc.private_route_table_id
}

# --- Encryption ---
module "kms" {
  source = "./modules/kms"
}

# --- IAM roles, policies, and log groups ---
module "iam" {
  source = "./modules/iam"

  kms_key_arn   = module.kms.key_arn
  sqs_queue_arn = module.sqs.queue_arn
}

# --- Messaging ---
module "sqs" {
  source = "./modules/sqs"

  kms_key_id           = module.kms.key_id
  api_task_role_arn    = module.iam.api_task_role_arn
  worker_task_role_arn = module.iam.worker_task_role_arn
}

# --- Data stores ---
module "database" {
  source = "./modules/database"

  db_identifier          = var.db_identifier
  engine                 = var.engine
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  db_name                = var.db_name
  db_username            = var.db_username
  db_password_wo_version = var.db_password_wo_version
  public_accessible      = var.public_accessible
  kms_key_arn            = module.kms.key_arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  security_group_ids     = [module.vpc.rds_security_group_id]
}

module "elasticcache" {
  source = "./modules/elasticcache"

  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.elasticache_security_group_id]
  kms_key_id         = module.kms.key_arn
}

# --- App configuration (SecureString parameters consumed by ECS tasks) ---
module "ssm" {
  source = "./modules/ssm"

  kms_key_id = module.kms.key_id

  db_username            = var.db_username
  db_password            = module.database.master_password
  db_endpoint            = module.database.endpoint
  db_name                = var.db_name
  db_password_wo_version = var.db_password_wo_version

  sqs_queue_url = module.sqs.queue_url

  redis_auth_token = module.elasticcache.auth_token
  redis_endpoint   = module.elasticcache.primary_endpoint_address
  redis_port       = module.elasticcache.port
}

# --- Compute ---
module "ecs" {
  source = "./modules/ecs"

  vpc_id                      = module.vpc.vpc_id
  public_subnet_ids           = module.vpc.default_public_subnet_ids
  private_subnet_ids          = module.vpc.private_subnet_ids
  alb_security_group_id       = module.vpc.alb_security_group_id
  api_security_group_id       = module.vpc.ecs_tasks_security_group_id
  dashboard_security_group_id = module.vpc.dashboard_tasks_security_group_id
  worker_security_group_id    = module.vpc.worker_tasks_security_group_id
  alb_logs_bucket_id          = module.observability.alb_logs_bucket_id
  certificate_arn             = data.aws_acm_certificate.cert.arn
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  api_task_role_arn           = module.iam.api_task_role_arn
  worker_task_role_arn        = module.iam.worker_task_role_arn
  api_repository_url          = data.aws_ecr_repository.api.repository_url
  dashboard_repository_url    = data.aws_ecr_repository.dashboard.repository_url
  worker_repository_url       = data.aws_ecr_repository.worker.repository_url
  api_image_tag               = var.api_image_tag
  dashboard_image_tag         = var.dashboard_image_tag
  worker_image_tag            = var.worker_image_tag
  database_url_parameter_arn  = module.ssm.database_url_parameter_arn
  sqs_queue_url_parameter_arn = module.ssm.sqs_queue_url_parameter_arn
  redis_url_parameter_arn     = module.ssm.redis_url_parameter_arn
  codedeploy_service_role_arn = module.iam.codedeploy_role_arn
}

# --- ALB access logs, regional WAF, and WAF logging ---
module "observability" {
  source = "./modules/observability"

  kms_key_arn = module.kms.key_arn
  alb_arn     = module.ecs.alb_arn
}

# --- Edge (CloudFront + WAF) ---
module "cloudfront" {
  source = "./modules/cloudfront"
}

# --- DNS ---
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

# --- Remote state bucket access controls ---
module "state_bucket" {
  source = "./modules/state_bucket"

  bucket_name       = var.terraform_state_bucket_name
  access_role_arns  = var.terraform_state_access_role_arns
  enforce_allowlist = var.terraform_state_enforce_allowlist
}
