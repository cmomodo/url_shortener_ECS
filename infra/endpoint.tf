#vpc endpoint for security group
resource "aws_vpc_endpoint" "security_group_endpoint" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.ec2"
}


#vpc endpoint for ecr
resource "aws_vpc_endpoint" "ecr_endpoint" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.ecr"
}

# Gateway endpoint for s3 routing
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}

#resource for ssm
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "interface"
  route_table_ids   = [aws_route_table.private.id]
}
