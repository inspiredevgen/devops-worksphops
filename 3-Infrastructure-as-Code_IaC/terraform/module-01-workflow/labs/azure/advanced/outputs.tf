output "identity_name" {
  description = "EN: Current managed identity / FR: Identité managée actuelle"
  value       = azurerm_user_assigned_identity.app.name
}

output "identity_principal_id" {
  description = "EN: Principal ID (changes on rotation) / FR: ID du principal (change à la rotation)"
  value       = azurerm_user_assigned_identity.app.principal_id
}

output "storage_account_id" {
  description = "EN: Protected storage account ID / FR: ID du compte de stockage protégé"
  value       = azurerm_storage_account.critical.id
}

output "release_container_id" {
  description = "EN: Container ID / FR: ID du conteneur"
  value       = azurerm_storage_container.release_current.id
}
