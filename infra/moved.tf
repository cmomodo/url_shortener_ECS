# State migrations from the flat root layout into modules.
# Safe to delete once every workspace has applied at least once on this layout.

# --- kms ---
moved {
  from = aws_kms_key.app
  to   = module.kms.aws_kms_key.app
}

moved {
  from = aws_kms_alias.app
  to   = module.kms.aws_kms_alias.app
}

# --- iam ---
moved {
  from = aws_cloudwatch_log_group.api
  to   = module.iam.aws_cloudwatch_log_group.api
}

moved {
  from = aws_cloudwatch_log_group.dashboard
  to   = module.iam.aws_cloudwatch_log_group.dashboard
}

moved {
  from = aws_cloudwatch_log_group.worker
  to   = module.iam.aws_cloudwatch_log_group.worker
}

moved {
  from = aws_iam_role.ecs_task_execution_role
  to   = module.iam.aws_iam_role.ecs_task_execution_role
}

moved {
  from = aws_iam_role_policy_attachment.ecs_task_execution_role
  to   = module.iam.aws_iam_role_policy_attachment.ecs_task_execution_role
}

moved {
  from = aws_iam_role_policy.ecs_ssm_policy
  to   = module.iam.aws_iam_role_policy.ecs_ssm_policy
}

moved {
  from = aws_iam_role.api_task_role
  to   = module.iam.aws_iam_role.api_task_role
}

moved {
  from = aws_iam_role_policy.api_task_sqs_policy
  to   = module.iam.aws_iam_role_policy.api_task_sqs_policy
}

moved {
  from = aws_iam_role.worker_task_role
  to   = module.iam.aws_iam_role.worker_task_role
}

moved {
  from = aws_iam_role_policy.worker_task_sqs_policy
  to   = module.iam.aws_iam_role_policy.worker_task_sqs_policy
}

moved {
  from = aws_iam_role.codedeploy
  to   = module.iam.aws_iam_role.codedeploy
}

moved {
  from = aws_iam_role_policy_attachment.codedeploy_ecs
  to   = module.iam.aws_iam_role_policy_attachment.codedeploy_ecs
}

moved {
  from = aws_iam_policy.deployer
  to   = module.iam.aws_iam_policy.deployer
}

# --- sqs ---
moved {
  from = aws_sqs_queue.terraform_queue
  to   = module.sqs.aws_sqs_queue.terraform_queue
}

moved {
  from = aws_sqs_queue_policy.terraform_queue
  to   = module.sqs.aws_sqs_queue_policy.terraform_queue
}

moved {
  from = aws_sqs_queue.secondary_queue_deadletter
  to   = module.sqs.aws_sqs_queue.secondary_queue_deadletter
}

moved {
  from = aws_sqs_queue_redrive_allow_policy.terraform_queue_redrive_allow_policy
  to   = module.sqs.aws_sqs_queue_redrive_allow_policy.terraform_queue_redrive_allow_policy
}

# --- database ---
moved {
  from = aws_iam_role.rds_enhanced_monitoring
  to   = module.database.aws_iam_role.rds_enhanced_monitoring
}

moved {
  from = aws_iam_role_policy_attachment.rds_enhanced_monitoring
  to   = module.database.aws_iam_role_policy_attachment.rds_enhanced_monitoring
}

moved {
  from = aws_db_parameter_group.url_shortener
  to   = module.database.aws_db_parameter_group.url_shortener
}

moved {
  from = aws_db_instance.url_shortener
  to   = module.database.aws_db_instance.url_shortener
}

moved {
  from = aws_db_subnet_group.default
  to   = module.database.aws_db_subnet_group.default
}

# --- elasticcache (redis auth token now lives in the module) ---
moved {
  from = random_password.redis_auth
  to   = module.elasticcache.random_password.redis_auth
}

# --- ssm ---
moved {
  from = aws_ssm_parameter.database_url
  to   = module.ssm.aws_ssm_parameter.database_url
}

moved {
  from = aws_ssm_parameter.sqs_queue_url
  to   = module.ssm.aws_ssm_parameter.sqs_queue_url
}

moved {
  from = aws_ssm_parameter.redis_url
  to   = module.ssm.aws_ssm_parameter.redis_url
}

# --- endpoints ---
moved {
  from = aws_vpc_endpoint.interface
  to   = module.endpoints.aws_vpc_endpoint.interface
}

moved {
  from = aws_vpc_endpoint.s3
  to   = module.endpoints.aws_vpc_endpoint.s3
}

moved {
  from = aws_vpc_endpoint.kms
  to   = module.endpoints.aws_vpc_endpoint.kms
}

# --- observability (was gateway_endpoint.tf) ---
moved {
  from = aws_s3_bucket.alb_logs
  to   = module.observability.aws_s3_bucket.alb_logs
}

moved {
  from = aws_s3_bucket_versioning.alb_logs
  to   = module.observability.aws_s3_bucket_versioning.alb_logs
}

moved {
  from = aws_s3_bucket_public_access_block.alb_logs
  to   = module.observability.aws_s3_bucket_public_access_block.alb_logs
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.alb_logs
  to   = module.observability.aws_s3_bucket_server_side_encryption_configuration.alb_logs
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.alb_logs
  to   = module.observability.aws_s3_bucket_lifecycle_configuration.alb_logs
}

moved {
  from = aws_s3_bucket_notification.alb_logs
  to   = module.observability.aws_s3_bucket_notification.alb_logs
}

moved {
  from = aws_s3_bucket.alb_logs_access
  to   = module.observability.aws_s3_bucket.alb_logs_access
}

moved {
  from = aws_s3_bucket_versioning.alb_logs_access
  to   = module.observability.aws_s3_bucket_versioning.alb_logs_access
}

moved {
  from = aws_s3_bucket_notification.alb_logs_access
  to   = module.observability.aws_s3_bucket_notification.alb_logs_access
}

moved {
  from = aws_s3_bucket_public_access_block.alb_logs_access
  to   = module.observability.aws_s3_bucket_public_access_block.alb_logs_access
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.alb_logs_access
  to   = module.observability.aws_s3_bucket_server_side_encryption_configuration.alb_logs_access
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.alb_logs_access
  to   = module.observability.aws_s3_bucket_lifecycle_configuration.alb_logs_access
}

moved {
  from = aws_s3_bucket_logging.alb_logs
  to   = module.observability.aws_s3_bucket_logging.alb_logs
}

moved {
  from = aws_s3_bucket_policy.alb_logs
  to   = module.observability.aws_s3_bucket_policy.alb_logs
}

moved {
  from = aws_wafv2_web_acl.alb
  to   = module.observability.aws_wafv2_web_acl.alb
}

moved {
  from = aws_wafv2_web_acl_association.alb
  to   = module.observability.aws_wafv2_web_acl_association.alb
}

moved {
  from = aws_s3_bucket.waf_logs
  to   = module.observability.aws_s3_bucket.waf_logs
}

moved {
  from = aws_s3_bucket_versioning.waf_logs
  to   = module.observability.aws_s3_bucket_versioning.waf_logs
}

moved {
  from = aws_s3_bucket_notification.waf_logs
  to   = module.observability.aws_s3_bucket_notification.waf_logs
}

moved {
  from = aws_s3_bucket_logging.waf_logs
  to   = module.observability.aws_s3_bucket_logging.waf_logs
}

moved {
  from = aws_s3_bucket_public_access_block.waf_logs
  to   = module.observability.aws_s3_bucket_public_access_block.waf_logs
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.waf_logs
  to   = module.observability.aws_s3_bucket_server_side_encryption_configuration.waf_logs
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.waf_logs
  to   = module.observability.aws_s3_bucket_lifecycle_configuration.waf_logs
}

moved {
  from = aws_iam_role.firehose_waf_logs
  to   = module.observability.aws_iam_role.firehose_waf_logs
}

moved {
  from = aws_iam_role_policy.firehose_waf_logs
  to   = module.observability.aws_iam_role_policy.firehose_waf_logs
}

moved {
  from = aws_kinesis_firehose_delivery_stream.waf_logs
  to   = module.observability.aws_kinesis_firehose_delivery_stream.waf_logs
}

moved {
  from = aws_wafv2_web_acl_logging_configuration.alb
  to   = module.observability.aws_wafv2_web_acl_logging_configuration.alb
}

# --- state_bucket ---
moved {
  from = aws_s3_bucket_policy.terraform_state
  to   = module.state_bucket.aws_s3_bucket_policy.terraform_state
}

# --- alb (extracted from ecs) ---
moved {
  from = module.ecs.aws_lb.main
  to   = module.alb.aws_lb.main
}

moved {
  from = module.ecs.aws_lb_target_group.api
  to   = module.alb.aws_lb_target_group.api
}

moved {
  from = module.ecs.aws_lb_target_group.api_green
  to   = module.alb.aws_lb_target_group.api_green
}

moved {
  from = module.ecs.aws_lb_target_group.dashboard
  to   = module.alb.aws_lb_target_group.dashboard
}

moved {
  from = module.ecs.aws_lb_target_group.dashboard_green
  to   = module.alb.aws_lb_target_group.dashboard_green
}

moved {
  from = module.ecs.aws_lb_listener.http
  to   = module.alb.aws_lb_listener.http
}

moved {
  from = module.ecs.aws_lb_listener.https
  to   = module.alb.aws_lb_listener.https
}

moved {
  from = module.ecs.aws_lb_listener.api_test
  to   = module.alb.aws_lb_listener.api_test
}

moved {
  from = module.ecs.aws_lb_listener.dashboard_test
  to   = module.alb.aws_lb_listener.dashboard_test
}

moved {
  from = module.ecs.aws_lb_listener_rule.dashboard
  to   = module.alb.aws_lb_listener_rule.dashboard
}

