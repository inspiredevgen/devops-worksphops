output "resource_group_name" {
  description = "EN: Resource group / FR: Groupe de ressources"
  value       = azurerm_resource_group.app.name
}

output "storage_account_name" {
  description = "EN: Storage account / FR: Compte de stockage"
  value       = azurerm_storage_account.data.name
}

output "log_analytics_workspace_id" {
  description = "EN: Log Analytics workspace ID / FR: ID de l'espace Log Analytics"
  value       = azurerm_log_analytics_workspace.app.id
}
