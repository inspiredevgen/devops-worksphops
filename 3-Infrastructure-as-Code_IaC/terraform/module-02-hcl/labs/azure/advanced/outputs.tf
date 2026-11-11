output "app_slug" {
  description = "EN: Sanitized application name / FR: Nom d'application nettoyé"
  value       = local.app_slug
}

output "storage_account_name" {
  description = "EN: Generated storage account name / FR: Nom de compte de stockage généré"
  value       = azurerm_storage_account.config.name
}

output "subnet_plan" {
  description = "EN: Computed subnet CIDRs / FR: CIDR de sous-réseaux calculés"
  value       = local.subnet_cidrs
}

output "effective_settings" {
  description = "EN: YAML defaults merged with overrides / FR: Valeurs YAML par défaut fusionnées avec les surcharges"
  value       = local.settings
}

output "rendered_config" {
  description = "EN: The generated configuration file / FR: Le fichier de configuration généré"
  value       = local.rendered_config
}

output "config_blob_url" {
  description = "EN: Blob URL (private) / FR: URL du blob (privé)"
  value       = azurerm_storage_blob.app_config.url
}
