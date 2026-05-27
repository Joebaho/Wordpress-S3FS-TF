# modules/storage/outputs.tf
output "s3_bucket_name" {
  value = aws_s3_bucket.wordpress_media.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.wordpress_media.arn
}

output "s3fs_iam_policy_arn" {
  value = aws_iam_policy.s3fs_access.arn
}