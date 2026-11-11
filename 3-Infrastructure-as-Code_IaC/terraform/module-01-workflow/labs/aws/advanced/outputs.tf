output "security_group_id" {
  description = "EN: Current SG ID (changes on replacement) / FR: ID actuel du SG (change au remplacement)"
  value       = aws_security_group.web.id
}

output "security_group_name" {
  description = "EN: Generated SG name / FR: Nom généré du SG"
  value       = aws_security_group.web.name
}

output "ssm_parameter_name" {
  description = "EN: SSM parameter name / FR: Nom du paramètre SSM"
  value       = aws_ssm_parameter.app_config.name
}

output "critical_bucket" {
  description = "EN: Protected bucket / FR: Compartiment protégé"
  value       = aws_s3_bucket.critical.bucket
}
