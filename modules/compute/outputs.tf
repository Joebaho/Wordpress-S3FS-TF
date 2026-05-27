output "alb_dns_name" {
  value = aws_lb.wordpress.dns_name
}

output "asg_id" {
  value = aws_autoscaling_group.wordpress.id
}

output "website_url" {
  value = "https://${var.domain_name}"
}

output "route53_record_fqdn" {
  value = var.create_route53_record ? aws_route53_record.wordpress[0].fqdn : var.domain_name
}
