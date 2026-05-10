resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "url-shortener-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_parameter_group" "url_shortener" {
  name_prefix = "url-shortener-pg16-"
  family      = "postgres16"

  parameter {
    name  = "log_min_duration_statement"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "url_shortener" {
  # Disposable / short-lived: no backups, no final snapshot, deletion protection off for easy teardown.
  #checkov:skip=CKV_AWS_133: Temporary environment — no automated RDS backups
  #checkov:skip=CKV_AWS_293: Temporary environment — deletion protection disabled
  #checkov:skip=CKV_AWS_157: Testing environment — single-AZ to reduce cost

  depends_on = [aws_db_subnet_group.default]

  identifier     = var.db_identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage      = var.allocated_storage
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.app.arn
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.url_shortener.name
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_service.id]
  publicly_accessible    = var.public_accessible

  copy_tags_to_snapshot = true

  backup_retention_period               = 0
  maintenance_window                    = "Mon:04:00-Mon:05:00"
  skip_final_snapshot                   = true
  deletion_protection                   = false
  multi_az                              = false
  auto_minor_version_upgrade            = true
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.app.arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_enhanced_monitoring.arn
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  tags = {
    Name = "url-shortener-db"
  }
}

# Database subnets come from the VPC layer and are created before RDS.
resource "aws_db_subnet_group" "default" {
  name       = "main-v2"
  subnet_ids = aws_subnet.private_blocks[*].id

  tags = {
    Name = "My DB subnet group"
  }
}
