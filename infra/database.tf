resource "aws_db_instance" "default" {
  depends_on              = [aws_db_subnet_group.default, aws_ecr_repository.api, aws_ecr_repository.dashboard, aws_ecr_repository.worker]
  identifier              = var.db_identifier
  allocated_storage       = var.allocated_storage
  db_name                 = var.db_name
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  username                = var.db_username
  password                = var.db_password
  parameter_group_name    = var.parameter_group_name
  skip_final_snapshot     = true
  backup_retention_period = 0
  vpc_security_group_ids  = [aws_security_group.rds_service.id]
  db_subnet_group_name    = aws_db_subnet_group.default.name
  publicly_accessible     = var.public_accessible

}

# Database subnets come from the VPC layer and are created before RDS.
resource "aws_db_subnet_group" "default" {
  name       = "main-v2"
  subnet_ids = aws_subnet.private_blocks[*].id

  tags = {
    Name = "My DB subnet group"
  }
}
