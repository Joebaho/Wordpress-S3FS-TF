# modules/database/variables.tf
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string }
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "deletion_protection" { type = bool }
variable "db_subnet_ids" { type = list(string) }
variable "db_security_group_id" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
