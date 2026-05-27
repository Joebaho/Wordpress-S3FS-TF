# modules/database/outputs.tf
output "rds_endpoint" {
  value = aws_db_instance.wordpress.endpoint
}

output "rds_address" {
  value = aws_db_instance.wordpress.address
}