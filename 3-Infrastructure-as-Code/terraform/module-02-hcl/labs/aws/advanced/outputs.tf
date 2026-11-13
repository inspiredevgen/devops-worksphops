output "app_slug" {
  description = "EN: Sanitized application name / FR: Nom d'application nettoyé"
  value       = local.app_slug
}

output "subnet_plan" {
  description = "EN: Computed subnet CIDRs / FR: CIDR de sous-réseaux calculés"
  value       = local.subnet_cidrs
}

output "azs_used" {
  description = "EN: Availability Zones used / FR: Zones de disponibilité utilisées"
  value       = local.azs
}

output "effective_settings" {
  description = "EN: YAML defaults merged with overrides / FR: Valeurs YAML par défaut fusionnées avec les surcharges"
  value       = local.settings
}

output "rendered_config" {
  description = "EN: The generated configuration file / FR: Le fichier de configuration généré"
  value       = local.rendered_config
}

output "config_s3_uri" {
  description = "EN: Where the config is stored / FR: Emplacement de la configuration"
  value       = "s3://${aws_s3_bucket.config.bucket}/${aws_s3_object.app_config.key}"
}
