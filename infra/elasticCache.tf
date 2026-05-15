#importing the elasticcache module
module "elasticcache" {
  source = "./modules/elasticcache"
  
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.ecs_tasks_security_group_id]
}