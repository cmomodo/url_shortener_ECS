# CodeDeploy applications and deployment groups for ECS blue/green rollouts.
# Each service has a blue target group, a green target group, and a test route.

resource "aws_codedeploy_app" "api" {
  name             = "url-shortener-api"
  compute_platform = "ECS"
}

resource "aws_codedeploy_app" "dashboard" {
  name             = "url-shortener-dashboard"
  compute_platform = "ECS"
}


resource "aws_codedeploy_deployment_group" "api" {
  app_name               = aws_codedeploy_app.api.name
  deployment_group_name  = "url-shortener-api"
  service_role_arn       = var.codedeploy_service_role_arn
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_REQUEST"]
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main_cluster.name
    service_name = aws_ecs_service.api.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.https.arn]
      }

      test_traffic_route {
        listener_arns = [aws_lb_listener.api_test.arn]
      }

      target_group {
        name = aws_lb_target_group.api.name
      }

      target_group {
        name = aws_lb_target_group.api_green.name
      }
    }
  }
}

resource "aws_codedeploy_deployment_group" "dashboard" {
  app_name               = aws_codedeploy_app.dashboard.name
  deployment_group_name  = "url-shortener-dashboard"
  service_role_arn       = var.codedeploy_service_role_arn
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_REQUEST"]
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main_cluster.name
    service_name = aws_ecs_service.dashboard.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.https.arn]
      }

      test_traffic_route {
        listener_arns = [aws_lb_listener.dashboard_test.arn]
      }

      target_group {
        name = aws_lb_target_group.dashboard.name
      }

      target_group {
        name = aws_lb_target_group.dashboard_green.name
      }
    }
  }
}


