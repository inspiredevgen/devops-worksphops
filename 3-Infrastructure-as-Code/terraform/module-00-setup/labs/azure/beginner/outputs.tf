# EN: Outputs print useful values after `terraform apply` / `terraform output`.
# FR: Les sorties affichent des valeurs utiles après `terraform apply` / `terraform output`.

output "tenant_id" {
  description = "EN: Microsoft Entra tenant ID / FR: ID du locataire Microsoft Entra"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "EN: Subscription ID / FR: ID de l'abonnement"
  value       = data.azurerm_subscription.current.subscription_id
}

output "subscription_name" {
  description = "EN: Subscription display name / FR: Nom de l'abonnement"
  value       = data.azurerm_subscription.current.display_name
}

output "caller_object_id" {
  description = "EN: Object ID of the identity Terraform is using / FR: ID d'objet de l'identité utilisée"
  value       = data.azurerm_client_config.current.object_id
}
