module "elasticcache" {
  source = "./modules/elasticcache"

  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.elasticache_security_group_id]
  auth_token         = random_password.redis_auth.result
  kms_key_id         = aws_kms_key.app.arn
}