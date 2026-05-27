# modules/security/variables.tf
variable "vpc_id" { type = string }
variable "ssh_ingress_cidr" { type = string }
variable "environment" { type = string }
variable "project_name" { type = string }
