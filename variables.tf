variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name. Keep this short because AWS load balancer names have length limits."
  type        = string
  default     = "neatfleets-wp"
}

variable "domain_name" {
  description = "Fully qualified domain name for WordPress"
  type        = string
  default     = "wordpress.neatfleets-services.com"
}

variable "hosted_zone_name" {
  description = "Route 53 public hosted zone name"
  type        = string
  default     = "neatfleets-services.com"
}

variable "certificate_arn" {
  description = "ACM certificate ARN in the same region as the ALB"
  type        = string
  default     = "arn:aws:acm:us-west-2:546310954125:certificate/97175fc9-4f18-48e3-8267-9aaffba49516"
}

variable "create_route53_record" {
  description = "Create or overwrite the Route 53 alias record for the WordPress domain"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  sensitive   = true
}

variable "ssh_ingress_cidr" {
  description = "CIDR block allowed to SSH to WordPress instances. Instances are private, so use a bastion/VPN CIDR when needed."
  type        = string
  default     = "10.0.0.0/16"
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "db_name" {
  description = "Database name"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "S3 bucket name for WordPress media files. Must be globally unique."
  type        = string
}

variable "s3_force_destroy" {
  description = "Allow Terraform to delete the S3 bucket even when it contains objects"
  type        = bool
  default     = false
}

variable "wp_site_title" {
  description = "WordPress site title"
  type        = string
  default     = "NeatFleets Services"
}

variable "wp_admin_user" {
  description = "Initial WordPress administrator username"
  type        = string
  default     = "admin"
}

variable "wp_admin_password" {
  description = "Initial WordPress administrator password"
  type        = string
  sensitive   = true
}

variable "wp_admin_email" {
  description = "Initial WordPress administrator email"
  type        = string
}
