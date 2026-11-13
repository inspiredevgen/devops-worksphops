# -----------------------------------------------------------------------------
# Lab 0.I-AZ — A least-privilege service principal for Terraform
# Lab 0.I-AZ — Un principal de service à moindre privilège pour Terraform
#
# EN: Creates an Entra ID app registration + service principal + rotating
#     client secret, and grants it "Contributor" (create/manage resources,
#     but NOT grant access to anyone). Cost: $0.
#     ⚠️ The client secret is stored in the Terraform state file. Module 10
#        covers state encryption; Module 11 replaces secrets with OIDC.
# FR: Crée une inscription d'application Entra ID + un principal de service +
#     un secret client avec rotation, et lui accorde « Contributeur » (créer/gérer
#     des ressources, mais PAS accorder d'accès). Coût : 0 $.
#     ⚠️ Le secret client est stocké dans le fichier d'état Terraform. Le module 10
#        couvre le chiffrement de l'état ; le module 11 remplace les secrets par OIDC.
# -----------------------------------------------------------------------------

data "azuread_client_config" "current" {}
data "azurerm_subscription" "current" {}

locals {
  role_scope = coalesce(var.assignment_scope_id, data.azurerm_subscription.current.id)
}

# EN: The application registration (the "identity definition").
# FR: L'inscription d'application (la « définition d'identité »).
resource "azuread_application" "terraform" {
  display_name = var.sp_display_name
  owners       = [data.azuread_client_config.current.object_id]
}

# EN: The service principal (the identity instance in YOUR tenant).
# FR: Le principal de service (l'instance de l'identité dans VOTRE locataire).
resource "azuread_service_principal" "terraform" {
  client_id = azuread_application.terraform.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# EN: Changes every N days, which forces a new secret to be created.
# FR: Change tous les N jours, ce qui force la création d'un nouveau secret.
resource "time_rotating" "secret" {
  rotation_days = var.secret_rotation_days
}

resource "azuread_service_principal_password" "terraform" {
  service_principal_id = azuread_service_principal.terraform.id
  end_date             = time_rotating.secret.rotation_rfc3339

  rotate_when_changed = {
    rotation = time_rotating.secret.id
  }
}

# EN: Grant the role at the chosen scope. principal_type avoids failures
#     caused by Entra ID replication delay right after creation.
# FR: Accorder le rôle à la portée choisie. principal_type évite les échecs
#     dus au délai de réplication d'Entra ID juste après la création.
resource "azurerm_role_assignment" "terraform" {
  scope                = local.role_scope
  role_definition_name = var.role_definition_name
  principal_id         = azuread_service_principal.terraform.object_id
  principal_type       = "ServicePrincipal"
}
