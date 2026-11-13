output "client_id" {
  description = "EN: Service principal client (application) ID / FR: ID client (application) du principal de service"
  value       = azuread_application.terraform.client_id
}

output "tenant_id" {
  description = "EN: Tenant ID / FR: ID du locataire"
  value       = data.azuread_client_config.current.tenant_id
}

output "subscription_id" {
  description = "EN: Subscription ID / FR: ID de l'abonnement"
  value       = data.azurerm_subscription.current.subscription_id
}

output "role_scope" {
  description = "EN: Where the role was granted / FR: Portée de l'attribution"
  value       = local.role_scope
}

# EN: Marked sensitive: hidden in plan/apply output. Read it with
#     `terraform output -raw client_secret` — but it is still in the state file!
# FR: Marqué sensible : masqué dans le plan/apply. Lisez-le avec
#     `terraform output -raw client_secret` — mais il reste dans le fichier d'état !
output "client_secret" {
  description = "EN: Client secret (sensitive) / FR: Secret client (sensible)"
  value       = azuread_service_principal_password.terraform.value
  sensitive   = true
}

output "secret_expires" {
  description = "EN: Secret expiry date / FR: Date d'expiration du secret"
  value       = time_rotating.secret.rotation_rfc3339
}
