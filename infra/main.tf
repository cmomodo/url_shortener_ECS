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

  vpc_id            = data.aws_vpc.main.id
  cidr_block        = cidrsubnet(data.aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# RDS security group inside the VPC layer.
resource "aws_security_group" "rds_service" {
  name        = "rds-service"
  description = "Allow database connections inside the default VPC"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
