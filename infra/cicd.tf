#container-deploy pipeline (build images -> CodeDeploy blue/green api + rolling dashboard/worker)
module "cicd" {
  source = "./modules/cicd"

  aws_region    = data.aws_region.current.region
  account_id    = data.aws_caller_identity.current.account_id
  github_repo   = var.github_repo
  github_branch = var.github_branch

  artifact_kms_key_arn = aws_kms_key.app.arn

  ecr_api_repo_url       = data.aws_ecr_repository.api.repository_url
  ecr_dashboard_repo_url = data.aws_ecr_repository.dashboard.repository_url
  ecr_worker_repo_url    = data.aws_ecr_repository.worker.repository_url

  ecs_cluster_name       = module.ecs.cluster_name
  dashboard_service_name = module.ecs.dashboard_service_name
  worker_service_name    = module.ecs.worker_service_name

  codedeploy_app_name              = module.ecs.codedeploy_app_name
  codedeploy_deployment_group_name = module.ecs.codedeploy_deployment_group_name

  execution_role_arn   = aws_iam_role.ecs_task_execution_role.arn
  api_task_role_arn    = aws_iam_role.api_task_role.arn
  worker_task_role_arn = aws_iam_role.worker_task_role.arn

  database_url_parameter_arn  = aws_ssm_parameter.database_url.arn
  sqs_queue_url_parameter_arn = aws_ssm_parameter.sqs_queue_url.arn
  redis_url_parameter_arn     = aws_ssm_parameter.redis_url.arn
}

output "cicd_github_connection_arn" {
  value       = module.cicd.github_connection_arn
  description = "Authorize this CodeConnections GitHub connection once in the console (PENDING -> AVAILABLE)."
}

output "cicd_pipeline_name" {
  value       = module.cicd.pipeline_name
  description = "Container-deploy pipeline name."
}
