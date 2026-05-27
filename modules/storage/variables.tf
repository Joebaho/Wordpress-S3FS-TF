# modules/storage/variables.tf
variable "s3_bucket_name" { type = string }
variable "force_destroy" { type = bool }
variable "environment" { type = string }
variable "project_name" { type = string }
