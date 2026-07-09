data "aws_region" "current" {}

locals {
  #interface endpoint services
  interface_endpoint_services = {
    ecr_api = "ecr.api"
    ecr_dkr = "ecr.dkr"
    logs    = "logs"
    ssm     = "ssm"
    sqs     = "sqs"
  }
}

#creating the vpc endpoint for each interface endpoint service
resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.security_group_id]
  private_dns_enabled = true

  tags = {
    Name = "url-shortener-${each.key}-endpoint"
  }
}

#gateway endpoint for s3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [var.private_route_table_id]

  tags = {
    Name = "url-shortener-s3-endpoint"
  }
}

#kms decrytion
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.security_group_id]
  private_dns_enabled = true

  tags = {
    Name = "url-shortener-kms-endpoint"
  }
}
