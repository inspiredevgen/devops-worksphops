output "bucket_name" {
  description = "EN: Bucket name / FR: Nom du compartiment"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "EN: Bucket ARN / FR: ARN du compartiment"
  value       = aws_s3_bucket.this.arn
}

output "restricted" {
  description = "EN: Whether access is locked to a VPC endpoint / FR: Accès limité à un point de terminaison VPC ?"
  value       = var.restrict_to_vpc_endpoint
}
