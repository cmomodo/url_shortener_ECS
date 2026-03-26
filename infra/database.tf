resource "aws_db_instance" "default" {

  depends_on              = [aws_db_subnet_group.default]
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
  vpc_security_group_ids  = [var.rds_security_group_id]
  db_subnet_group_name    = aws_db_subnet_group.default.name
  publicly_accessible     = var.public_accessible

}

#subnet group
resource "aws_db_subnet_group" "dashboard" {
  name       = "main-v2"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "My DB subnet group"
  }
}
