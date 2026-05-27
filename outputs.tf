output "website_url" {
  description = "WordPress HTTPS URL"
  value       = module.compute.website_url
}

output "route53_record_fqdn" {
  description = "Route 53 alias record pointing to the ALB"
  value       = module.compute.route53_record_fqdn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.rds_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket name for WordPress media"
  value       = module.storage.s3_bucket_name
}
