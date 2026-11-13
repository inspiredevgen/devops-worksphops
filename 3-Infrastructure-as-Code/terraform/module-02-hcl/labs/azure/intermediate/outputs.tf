output "name_prefix" {
  description = "EN: Naming convention result / FR: Résultat de la convention de nommage"
  value       = local.name_prefix
}

output "effective_settings" {
  description = "EN: Settings chosen for this environment / FR: Paramètres choisis pour cet environnement"
  value = {
    replication        = local.settings.replication
    log_retention_days = local.log_retention_days
  }
}

output "storage_account_name" {
  description = "EN: Generated storage account name / FR: Nom de compte de stockage généré"
  value       = azurerm_storage_account.app.name
}

output "tenant_id" {
  description = "EN: Tenant (from a data source) / FR: Locataire (depuis une source de données)"
  value       = data.azurerm_client_config.current.tenant_id
}

# EN: The provider marks this attribute sensitive, so the output must be too.
# FR: Le provider marque cet attribut comme sensible : la sortie doit l'être aussi.
output "storage_connection_string" {
  description = "EN: For the exercise only / FR: Pour l'exercice uniquement"
  value       = azurerm_storage_account.app.primary_connection_string
  sensitive   = true
}
