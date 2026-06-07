data "aws_vpc" "main" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

#private subnets
resource "aws_subnet" "private_blocks" {
  count = 2

  vpc_id                  = data.aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "url-shortener-private"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private_blocks)

  subnet_id      = aws_subnet.private_blocks[count.index].id
  route_table_id = aws_route_table.private.id
}

# RDS security group inside the VPC layer.
resource "aws_security_group" "rds_service" {
  name        = "rds-service"
  description = "PostgreSQL from ECS API, dashboard, and worker tasks only"
  vpc_id      = data.aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_service_postgres_from_api" {
  security_group_id            = aws_security_group.rds_service.id
  description                  = "PostgreSQL from API tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_service_postgres_from_dashboard" {
  security_group_id            = aws_security_group.rds_service.id
  description                  = "PostgreSQL from dashboard tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.dashboard_tasks.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_service_postgres_from_worker" {
  security_group_id            = aws_security_group.rds_service.id
  description                  = "PostgreSQL from worker tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.worker_tasks.id
}

resource "aws_security_group" "elasticache" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to the ElastiCache replication group in the elasticcache module.
  name        = "url-shortener-elasticache"
  description = "Redis from ECS API, dashboard, and worker tasks only"
  vpc_id      = data.aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_redis_from_api" {
  security_group_id            = aws_security_group.elasticache.id
  description                  = "Redis from API tasks"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_redis_from_dashboard" {
  security_group_id            = aws_security_group.elasticache.id
  description                  = "Redis from dashboard tasks"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.dashboard_tasks.id
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_redis_from_worker" {
  security_group_id            = aws_security_group.elasticache.id
  description                  = "Redis from worker tasks"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.worker_tasks.id
}

#security group for the ecs tasks
resource "aws_security_group" "ecs_tasks" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to ECS services in the ECS module.
  name        = "url-shortener-ecs-tasks"
  description = "Ingress from ALB; egress for AWS APIs, Postgres, and Redis"
  vpc_id      = data.aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "ecs_tasks_from_alb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "API container port from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_tasks_https" {
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "HTTPS for AWS APIs and interface endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ecs_tasks_postgres" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "PostgreSQL to RDS"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds_service.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_tasks_redis" {
  security_group_id            = aws_security_group.ecs_tasks.id
  description                  = "Redis to ElastiCache"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.elasticache.id
}

#dashboard security group
resource "aws_security_group" "dashboard_tasks" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to ECS services in the ECS module.
  name        = "url-shortener-dashboard-tasks"
  description = "Ingress from ALB; egress for AWS APIs, Postgres, and Redis"
  vpc_id      = data.aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "dashboard_tasks_from_alb" {
  security_group_id            = aws_security_group.dashboard_tasks.id
  description                  = "Dashboard container port from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 8081
  to_port                      = 8081
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "dashboard_tasks_https" {
  security_group_id = aws_security_group.dashboard_tasks.id
  description       = "HTTPS for AWS APIs and interface endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dashboard_tasks_postgres" {
  security_group_id            = aws_security_group.dashboard_tasks.id
  description                  = "PostgreSQL to RDS"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds_service.id
}

resource "aws_vpc_security_group_egress_rule" "dashboard_tasks_redis" {
  security_group_id            = aws_security_group.dashboard_tasks.id
  description                  = "Redis to ElastiCache"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.elasticache.id
}

#worker task security group
resource "aws_security_group" "worker_tasks" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to ECS services in the ECS module.
  name        = "url-shortener-worker-tasks"
  description = "Worker egress for AWS APIs, Postgres, Redis, and SQS"
  vpc_id      = data.aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "worker_tasks_https" {
  security_group_id = aws_security_group.worker_tasks.id
  description       = "HTTPS for AWS APIs and interface endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "worker_tasks_postgres" {
  security_group_id            = aws_security_group.worker_tasks.id
  description                  = "PostgreSQL to RDS"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds_service.id
}

resource "aws_vpc_security_group_egress_rule" "worker_tasks_redis" {
  security_group_id            = aws_security_group.worker_tasks.id
  description                  = "Redis to ElastiCache"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.elasticache.id
}

resource "aws_security_group" "vpce_interface" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to VPC Endpoints in endpoint.tf in the root module.
  name        = "url-shortener-vpce-interface"
  description = "Allow ECS tasks to reach interface endpoints over HTTPS"
  vpc_id      = data.aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "vpce_interface_from_ecs" {
  security_group_id            = aws_security_group.vpce_interface.id
  description                  = "HTTPS from API tasks"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_vpc_security_group_ingress_rule" "vpce_interface_from_dashboard" {
  security_group_id            = aws_security_group.vpce_interface.id
  description                  = "HTTPS from dashboard tasks"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.dashboard_tasks.id
}

resource "aws_vpc_security_group_ingress_rule" "vpce_interface_from_worker" {
  security_group_id            = aws_security_group.vpce_interface.id
  description                  = "HTTPS from worker tasks"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.worker_tasks.id
}

resource "aws_vpc_security_group_egress_rule" "vpce_interface_return_vpc" {
  security_group_id = aws_security_group.vpce_interface.id
  description       = "Return traffic within the VPC"
  ip_protocol       = "tcp"
  from_port         = 1024
  to_port           = 65535
  cidr_ipv4         = data.aws_vpc.main.cidr_block
}

# AWS-managed prefix list for CloudFront origin-facing IPs — stays up to date automatically
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

#security group for alb
resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to the ALB in the ECS module.
  name        = "url-shortener-alb"
  description = "Web traffic to the application load balancer (ingress from CloudFront only)"
  vpc_id      = data.aws_vpc.main.id
}

# CloudFront origin uses HTTPS only (cloudfront.tf); no ingress on ALB:80 from the
# CloudFront prefix list. ALB:80 still accepts redirects for other paths but is not
# used by this distribution’s origin connection.

# Single rule for 443 (production) and 8443 (CodeDeploy test listener). Each
# prefix-list CIDR counts toward the per-SG rule quota (~60); a second rule
# referencing the same CloudFront list would exceed that limit.
resource "aws_vpc_security_group_ingress_rule" "alb_https_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS and API blue/green test listener from CloudFront"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 8443
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id = aws_security_group.alb.id
  description       = "To API and dashboard tasks in the VPC (avoids SG cycle with task groups)"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8081
  cidr_ipv4         = data.aws_vpc.main.cidr_block
}

#using built in subnets for the vpc
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
}
