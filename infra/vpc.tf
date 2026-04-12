data "aws_vpc" "main" {
  default = true
}

# Get availability zones
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
  description = "Allow database connections inside the default VPC"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "PostgreSQL from the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "HTTPS for RDS maintenance and patching"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#security group for the ecs tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "url-shortener-ecs-tasks"
  description = "Ingress from ALB; egress for AWS APIs, Postgres, and Redis"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "API container port from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS for AWS APIs and interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL to the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "Redis to the VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
}

#dashboard security group
resource "aws_security_group" "dashboard_tasks" {
  name        = "url-shortener-dashboard-tasks"
  description = "Ingress from ALB; egress for AWS APIs, Postgres, and Redis"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "Dashboard container port from ALB"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS for AWS APIs and interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL to the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "Redis to the VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
}

#worker task security group
resource "aws_security_group" "worker_tasks" {
  name        = "url-shortener-worker-tasks"
  description = "Worker egress for AWS APIs, Postgres, Redis, and SQS"
  vpc_id      = data.aws_vpc.main.id

  egress {
    description = "HTTPS for AWS APIs and interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL to the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "Redis to the VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
}

resource "aws_security_group" "vpce_interface" {
  name        = "url-shortener-vpce-interface"
  description = "Allow ECS tasks to reach interface endpoints over HTTPS"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "HTTPS from API tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  ingress {
    description     = "HTTPS from dashboard tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.dashboard_tasks.id]
  }

  ingress {
    description     = "HTTPS from worker tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_tasks.id]
  }

  egress {
    description = "Return traffic within the VPC"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    description = "HTTPS to the internet for AWS service backends"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#security group for alb
resource "aws_security_group" "alb" {
  name        = "url-shortener-alb"
  description = "Web traffic to the application load balancer (ingress limited by var.alb_allowed_ingress_cidrs)"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "HTTP redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_ingress_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_ingress_cidrs
  }

  egress {
    description = "To API and dashboard tasks in the VPC (avoids SG cycle with task groups)"
    from_port   = 8080
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
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
