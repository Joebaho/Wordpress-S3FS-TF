# modules/storage/main.tf
# S3 Bucket
resource "aws_s3_bucket" "wordpress_media" {
  bucket        = var.s3_bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project_name}-media-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.wordpress_media.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "media" {
  bucket = aws_s3_bucket.wordpress_media.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.wordpress_media.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM Policy for s3fs Access (attached to EC2 role)
resource "aws_iam_policy" "s3fs_access" {
  name        = "${var.project_name}-s3fs-policy"
  description = "Policy for EC2 instances to mount and access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [aws_s3_bucket.wordpress_media.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = ["${aws_s3_bucket.wordpress_media.arn}/*"]
      }
    ]
  })
}
