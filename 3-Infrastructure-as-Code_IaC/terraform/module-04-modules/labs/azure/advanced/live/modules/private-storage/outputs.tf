output "storage_account_id" {
  description = "EN: Storage account ID / FR: ID du compte de stockage"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "EN: Storage account name / FR: Nom du compte de stockage"
  value       = azurerm_storage_account.this.name
}

output "locked_down" {
  description = "EN: Whether network access is restricted / FR: Accès réseau restreint ?"
  value       = length(var.allowed_subnet_ids) > 0
}
