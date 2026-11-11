output "name_prefix" {
  description = "EN: Naming convention result / FR: Résultat de la convention de nommage"
  value       = local.name_prefix
}

output "effective_settings" {
  description = "EN: Settings chosen for this environment / FR: Paramètres choisis pour cet environnement"
  value       = local.settings
}

output "bucket_name" {
  description = "EN: Artifacts bucket / FR: Compartiment d'artefacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "config_parameter" {
  description = "EN: SSM parameter holding the app config / FR: Paramètre SSM contenant la config de l'appli"
  value       = aws_ssm_parameter.app_config.name
}

# EN: An output that references a sensitive value MUST be marked sensitive,
#     otherwise Terraform raises an error.
# FR: Une sortie qui référence une valeur sensible DOIT être marquée sensible,
#     sinon Terraform renvoie une erreur.
output "api_key_parameter_value" {
  description = "EN: For the exercise only / FR: Pour l'exercice uniquement"
  value       = aws_ssm_parameter.api_key.value
  sensitive   = true
}
