output "bucket" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "sse_algorithm" {
  value = var.kms_key_arn == null ? "AES256" : "aws:kms"
}
