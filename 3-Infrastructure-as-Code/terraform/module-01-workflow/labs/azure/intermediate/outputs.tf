output "resource_group_id" {
  description = "EN: Resource group ID / FR: ID du groupe de ressources"
  value       = azurerm_resource_group.lab.id
}

output "storage_account_id" {
  description = "EN: Storage account ID / FR: ID du compte de stockage"
  value       = azurerm_storage_account.lab.id
}

output "readme_url" {
  description = "EN: Blob URL (private) / FR: URL du blob (privé)"
  value       = azurerm_storage_blob.readme.url
}
