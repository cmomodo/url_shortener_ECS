#load balancer for the ecs service
resource "aws_lb" "main" {
  #checkov:skip=CKV_AWS_150: Deletion protection intentionally disabled for easier teardown in this environment
  name                       = "url-shortener"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = false
  drop_invalid_header_fields = true
  enable_http2               = true

  access_logs {
    bucket  = var.alb_logs_bucket_id
    prefix  = "alb"
    enabled = true
  }
}

#target group for the api load balancer
#checkov:skip=CKV_AWS_378: HTTP to container targets; TLS terminates at the public ALB
resource "aws_lb_target_group" "api" {
  name        = "url-shortener-api"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}



resource "aws_lb_target_group" "api_green" {
  #checkov:skip=CKV_AWS_378: HTTP to container targets; TLS terminates at the public ALB
  name        = "url-shortener-api-green"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "api_test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_green.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

resource "aws_lb_target_group" "dashboard" {
  #checkov:skip=CKV_AWS_378: HTTP to container targets; TLS terminates at the public ALB
  name        = "url-shortener-dashboard"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_target_group" "dashboard_green" {
  #checkov:skip=CKV_AWS_378: HTTP to container targets; TLS terminates at the public ALB
  name        = "url-shortener-dashboard-green"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener_rule" "dashboard" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/summary*", "/top*", "/recent*", "/url/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
  }

  lifecycle {
    ignore_changes = [action]
  }
}

resource "aws_lb_listener" "dashboard_test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8444
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard_green.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}


resource "aws_ecs_task_definition" "dashboard" {
  family                   = "dashboard"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_task_execution_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([{
    name                   = "dashboard"
    image                  = "${var.dashboard_repository_url}:${var.dashboard_image_tag}"
    essential              = true
    readonlyRootFilesystem = true
    mountPoints = [{
      sourceVolume  = "tmp"
      containerPath = "/tmp"
      readOnly      = false
    }]
    portMappings = [{ containerPort = 8081, protocol = "tcp" }]
    environment = [
      { name = "PORT", value = "8081" },
      { name = "AWS_REGION", value = "us-east-1" }
    ]
    secrets = [
      { name = "DATABASE_URL", valueFrom = var.database_url_parameter_arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/dashboard"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "dashboard" {
  name            = "dashboard"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.dashboard.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 60

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.dashboard_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dashboard.arn
    container_name   = "dashboard"
    container_port   = 8081
  }

  # CodeDeploy owns the active task definition and target group after create.
  lifecycle {
    ignore_changes = [task_definition, load_balancer, desired_count]
  }

  depends_on = [aws_lb_listener.https]
}

#ecs cluster we are using for the services
resource "aws_ecs_cluster" "main_cluster" {
  name = "url-shortener"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- Task Definition ---

resource "aws_ecs_task_definition" "api" {
  family                   = "api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.api_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([{
    name                   = "api"
    image                  = "${var.api_repository_url}:${var.api_image_tag}"
    essential              = true
    readonlyRootFilesystem = true
    mountPoints = [{
      sourceVolume  = "tmp"
      containerPath = "/tmp"
      readOnly      = false
    }]
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "PORT", value = "8080" },
      { name = "AWS_REGION", value = "us-east-1" },
      { name = "AWS_DEFAULT_REGION", value = "us-east-1" }
    ]
    secrets = [
      { name = "DATABASE_URL", valueFrom = var.database_url_parameter_arn },
      { name = "SQS_QUEUE_URL", valueFrom = var.sqs_queue_url_parameter_arn },
      { name = "REDIS_URL", valueFrom = var.redis_url_parameter_arn }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/api"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

#ecs service definition
resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Give replacement tasks time to pass the ALB health check before CodeDeploy
  # evaluates the green task set.
  health_check_grace_period_seconds = 60

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.api_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  # CodeDeploy owns the active task definition and target group after create.
  lifecycle {
    ignore_changes = [task_definition, load_balancer, desired_count]
  }

  depends_on = [aws_lb_listener.https]
}

#worker service
resource "aws_ecs_service" "worker" {
  name            = "worker"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.worker_security_group_id]
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

#task definition for the worker
resource "aws_ecs_task_definition" "worker" {
  family                   = "worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.worker_task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([
    {
      name                   = "worker"
      image                  = "${var.worker_repository_url}:${var.worker_image_tag}"
      essential              = true
      readonlyRootFilesystem = true
      mountPoints = [{
        sourceVolume  = "tmp"
        containerPath = "/tmp"
        readOnly      = false
      }]
      portMappings = [
        { containerPort = 8090, protocol = "tcp" }
      ]
      environment = [
        { name = "AWS_REGION", value = "us-east-1" },
        { name = "AWS_DEFAULT_REGION", value = "us-east-1" },
        { name = "HEALTH_PORT", value = "8090" }
      ]
      secrets = [
        { name = "DATABASE_URL", valueFrom = var.database_url_parameter_arn },
        { name = "SQS_QUEUE_URL", valueFrom = var.sqs_queue_url_parameter_arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/worker"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}
