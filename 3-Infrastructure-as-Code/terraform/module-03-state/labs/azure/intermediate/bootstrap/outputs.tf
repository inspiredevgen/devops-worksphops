output "storage_account_name" {
  description = "EN: State storage account / FR: Compte de stockage de l'état"
  value       = azurerm_storage_account.state.name
}

# EN: PARTIAL backend configuration. Save it with:
#       terraform output -raw backend_hcl > ../backend.hcl
#     Each configuration adds its own unique `key` at init time.
# FR: Configuration de backend PARTIELLE. Enregistrez-la avec :
#       terraform output -raw backend_hcl > ../backend.hcl
#     Chaque configuration ajoute sa propre `key` unique lors de l'init.
output "backend_hcl" {
  description = "EN: Partial backend config / FR: Configuration de backend partielle"
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
  EOT
}
