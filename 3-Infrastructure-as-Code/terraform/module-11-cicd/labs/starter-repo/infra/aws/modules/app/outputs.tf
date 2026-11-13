output "bucket" {
  value = aws_s3_bucket.this.id
}

output "parameter" {
  value = aws_ssm_parameter.message.name
}
