# Networking Module
module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  environment          = var.environment
  project_name         = var.project_name
}

# Security Module
module "security" {
  source = "./modules/security"

  vpc_id           = module.networking.vpc_id
  ssh_ingress_cidr = var.ssh_ingress_cidr
  environment      = var.environment
  project_name     = var.project_name
}

# Storage Module
module "storage" {
  source = "./modules/storage"

  s3_bucket_name = var.s3_bucket_name
  force_destroy  = var.s3_force_destroy
  environment    = var.environment
  project_name   = var.project_name
}

# Database Module
module "database" {
  source = "./modules/database"

  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  deletion_protection  = var.db_deletion_protection
  db_subnet_ids        = module.networking.private_subnet_ids
  db_security_group_id = module.security.rds_sg_id
  environment          = var.environment
  project_name         = var.project_name
}

# Compute Module
module "compute" {
  source = "./modules/compute"

  region                = var.region
  environment           = var.environment
  project_name          = var.project_name
  domain_name           = var.domain_name
  hosted_zone_name      = var.hosted_zone_name
  certificate_arn       = var.certificate_arn
  create_route53_record = var.create_route53_record
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.security.alb_sg_id
  asg_security_group_id = module.security.asg_sg_id
  instance_type         = var.instance_type
  key_name              = var.key_name
  asg_min_size          = var.asg_min_size
  asg_max_size          = var.asg_max_size
  asg_desired_capacity  = var.asg_desired_capacity
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  db_endpoint           = module.database.rds_address
  s3_bucket_name        = module.storage.s3_bucket_name
  s3fs_policy_arn       = module.storage.s3fs_iam_policy_arn
  wp_site_title         = var.wp_site_title
  wp_admin_user         = var.wp_admin_user
  wp_admin_password     = var.wp_admin_password
  wp_admin_email        = var.wp_admin_email
}
