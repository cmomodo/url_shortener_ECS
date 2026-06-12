# CodeDeploy shifts listener default actions at deploy time (see lifecycle
# ignore_changes on aws_lb_listener.https and api_test). That drift is invisible
# to Terraform's destroy graph, so target groups can be deleted while a listener
# still forwards to them. This hook resets listeners to the blue target group
# before those resources are destroyed.

data "aws_region" "current" {}

resource "terraform_data" "reset_alb_listeners_on_destroy" {
  input = {
    region         = data.aws_region.current.region
    https_listener = aws_lb_listener.https.arn
    test_listener  = aws_lb_listener.api_test.arn
    blue_tg_arn    = aws_lb_target_group.api.arn
  }

  depends_on = [
    aws_ecs_service.api,
    aws_lb_target_group.api,
    aws_lb_target_group.api_green,
    aws_lb_listener.https,
    aws_lb_listener.api_test,
  ]

  provisioner "local-exec" {
    when        = destroy
    on_failure  = continue
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      echo "Resetting ALB listeners to blue target group before destroy..."
      aws elbv2 modify-listener --region "${self.input.region}" \
        --listener-arn "${self.input.https_listener}" \
        --default-actions Type=forward,TargetGroupArn="${self.input.blue_tg_arn}" || true
      aws elbv2 modify-listener --region "${self.input.region}" \
        --listener-arn "${self.input.test_listener}" \
        --default-actions Type=forward,TargetGroupArn="${self.input.blue_tg_arn}" || true
      echo "ALB listeners reset."
    EOT
  }
}
