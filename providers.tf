# main.tf
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "baho-backup-bucket"
    key    = "wordpress-s3fs/terraform.tfstate"
    region = "us-west-2"
    #dynamodb_table = "wordpress-lock-table"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
}