output "resource_group_name" {
  description = "EN: Resource group / FR: Groupe de ressources"
  value       = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  description = "EN: Storage account name / FR: Nom du compte de stockage"
  value       = azurerm_storage_account.lab.name
}

output "blob_endpoint" {
  description = "EN: Primary blob endpoint / FR: Point de terminaison blob principal"
  value       = azurerm_storage_account.lab.primary_blob_endpoint
}
