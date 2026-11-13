output "bucket_name" {
  description = "EN: Data bucket / FR: Compartiment de données"
  value       = aws_s3_bucket.data.bucket
}

output "log_group_name" {
  description = "EN: Log group / FR: Groupe de journaux"
  value       = aws_cloudwatch_log_group.app.name
}

output "config_parameter" {
  description = "EN: SSM config parameter / FR: Paramètre SSM de configuration"
  value       = aws_ssm_parameter.config.name
}
