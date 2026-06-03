#import ecs module 
module "ecs" {
  source = "./modules/ecs"

  vpc_id                      = module.vpc.vpc_id
  public_subnet_ids           = module.vpc.default_public_subnet_ids
  private_subnet_ids          = module.vpc.private_subnet_ids
  alb_security_group_id       = module.vpc.alb_security_group_id
  api_security_group_id       = module.vpc.ecs_tasks_security_group_id
  dashboard_security_group_id = module.vpc.dashboard_tasks_security_group_id
  worker_security_group_id    = module.vpc.worker_tasks_security_group_id
  alb_logs_bucket_id          = aws_s3_bucket.alb_logs.id
  certificate_arn             = data.aws_acm_certificate.cert.arn
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  api_task_role_arn           = aws_iam_role.api_task_role.arn
  worker_task_role_arn        = aws_iam_role.worker_task_role.arn
  api_repository_url          = data.aws_ecr_repository.api.repository_url
  dashboard_repository_url    = data.aws_ecr_repository.dashboard.repository_url
  worker_repository_url       = data.aws_ecr_repository.worker.repository_url
  api_image_tag               = var.api_image_tag
  dashboard_image_tag         = "latest"
  worker_image_tag            = var.worker_image_tag
  database_url_parameter_arn  = aws_ssm_parameter.database_url.arn
  sqs_queue_url_parameter_arn = aws_ssm_parameter.sqs_queue_url.arn
  redis_url_parameter_arn     = aws_ssm_parameter.redis_url.arn
  codedeploy_service_role_arn = aws_iam_role.codedeploy.arn

  depends_on = [aws_s3_bucket_policy.alb_logs]
}