output "bucket_name" {
  description = "EN: Bucket name / FR: Nom du compartiment"
  value       = aws_s3_bucket.lab.bucket
}

output "bucket_arn" {
  description = "EN: Bucket ARN / FR: ARN du compartiment"
  value       = aws_s3_bucket.lab.arn
}

output "bucket_region" {
  description = "EN: Bucket region / FR: Région du compartiment"
  value       = aws_s3_bucket.lab.region
}
