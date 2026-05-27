# modules/security/outputs.tf
output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "asg_sg_id" {
  value = aws_security_group.asg.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}