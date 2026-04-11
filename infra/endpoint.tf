data "aws_region" "current" {}

locals {
  interface_endpoint_services = {
    ecr_api = "ecr.api"
    ecr_dkr = "ecr.dkr"
    logs    = "logs"
    ssm     = "ssm"
    sqs     = "sqs"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_blocks[*].id
  security_group_ids  = [aws_security_group.vpce_interface.id]
  private_dns_enabled = true

  tags = {
    Name = "url-shortener-${each.key}-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "url-shortener-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_blocks[*].id
  security_group_ids  = [aws_security_group.vpce_interface.id]
  private_dns_enabled = true

  tags = {
    Name = "url-shortener-kms-endpoint"
  }
}