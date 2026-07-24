#load balancer for the ecs service
resource "aws_lb" "main" {
  #checkov:skip=CKV_AWS_150: Deletion protection intentionally disabled for easier teardown in this environment
  #checkov:skip=CKV2_AWS_28: A regional WAF is associated with this ALB through the observability module.
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

  # CodeDeploy can swap the green TG onto this prod listener out-of-band. Declare
  # the dependency so this listener is destroyed before the green TG (avoids
  # ResourceInUse on `terraform destroy`).
  depends_on = [aws_lb_target_group.api_green]
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

  # CodeDeploy can swap the blue TG onto this test listener out-of-band. Declare
  # the dependency so this listener is destroyed before the blue TG.
  depends_on = [aws_lb_target_group.api]
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

  # CodeDeploy can swap the green dashboard TG onto this prod rule out-of-band.
  # Ensure the rule is destroyed before the green TG.
  depends_on = [aws_lb_target_group.dashboard_green]
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

  # CodeDeploy can swap the blue dashboard TG onto this test listener out-of-band.
  # Ensure the listener is destroyed before the blue TG.
  depends_on = [aws_lb_target_group.dashboard]
}
