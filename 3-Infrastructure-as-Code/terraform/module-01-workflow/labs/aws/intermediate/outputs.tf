output "bucket_name" {
  description = "EN: Bucket name / FR: Nom du compartiment"
  value       = aws_s3_bucket.lab.bucket
}

output "readme_version_id" {
  description = "EN: S3 version ID of README.txt (changes on every update) / FR: ID de version S3 de README.txt (change à chaque mise à jour)"
  value       = aws_s3_object.readme.version_id
}
