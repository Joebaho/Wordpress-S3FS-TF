# modules/database/main.tf
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Database subnet group for RDS"
  subnet_ids  = var.db_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "wordpress" {
  identifier                = "${var.project_name}-db"
  engine                    = "mysql"
  engine_version            = "8.0"
  instance_class            = var.db_instance_class
  allocated_storage         = var.db_allocated_storage
  storage_encrypted         = true
  storage_type              = "gp3"
  db_name                   = var.db_name
  username                  = var.db_username
  password                  = var.db_password
  port                      = 3306
  vpc_security_group_ids    = [var.db_security_group_id]
  db_subnet_group_name      = aws_db_subnet_group.main.name
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  multi_az                  = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"
  publicly_accessible       = false
  deletion_protection       = var.deletion_protection

  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
  }
}
