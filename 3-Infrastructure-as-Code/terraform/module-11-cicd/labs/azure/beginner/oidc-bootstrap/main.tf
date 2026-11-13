# =============================================================================
# Lab 11.B-AZ — Keyless CI: GitHub Actions → Azure with workload identity federation
# Lab 11.B-AZ — CI sans clé : GitHub Actions → Azure avec la fédération d'identité de charge de travail
#
#   GitHub job ──(signed OIDC token)──► Microsoft Entra ID
#   Entra matches issuer + subject against a FEDERATED CREDENTIAL ──► short-lived access token
#   No client secret exists anywhere. / Aucun secret client n'existe nulle part.
# =============================================================================

locals {
  issuer   = "https://token.actions.githubusercontent.com"
  audience = ["api://AzureADTokenExchange"]
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "11-cicd"
    ManagedBy = "terraform"
    Owner     = var.owner
  }

  plan_subjects = {
    pull-request = "repo:${var.github_repo}:pull_request"
    main         = "repo:${var.github_repo}:ref:refs/heads/main"
  }

  # EN: Data-plane scope of the state CONTAINER (not the whole storage account).
  # FR : Portée plan de données du CONTENEUR d'état (pas tout le compte de stockage).
  state_container_scope = "${data.azurerm_storage_account.state.id}/blobServices/default/containers/${var.state_container}"
}

data "azurerm_client_config" "current" {}

data "azurerm_storage_account" "state" {
  name                = var.state_storage_account
  resource_group_name = var.state_resource_group
}

resource "azurerm_resource_group" "identity" {
  name     = "rg-tf-cicd-identity"
  location = var.location
  tags     = local.tags
}

# EN: The bootstrap creates the target resource groups, so CI only ever gets RG-scoped rights.
# FR : Le bootstrap crée les groupes de ressources cibles : la CI n'obtient que des droits limités à un RG.
resource "azurerm_resource_group" "target" {
  for_each = var.environments

  name     = "rg-tf-cicd-${each.key}"
  location = var.location
  tags     = merge(local.tags, { Environment = each.key })
}

# ------------------------------------------------------------------------ plan
resource "azurerm_user_assigned_identity" "plan" {
  name                = "id-tf-gha-plan"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  tags                = local.tags
}

# EN: parent_id is renamed user_assigned_identity_id in recent 4.x releases; parent_id keeps working until v5.
# FR : parent_id devient user_assigned_identity_id dans les versions 4.x récentes ; parent_id fonctionne jusqu'à la v5.
resource "azurerm_federated_identity_credential" "plan_pr" {
  name                = "github-pull-request"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.plan.id
  audience            = local.audience
  issuer              = local.issuer
  subject             = local.plan_subjects["pull-request"]
}

# EN: Azure refuses CONCURRENT credential writes on one identity, so the second waits for the first.
# FR : Azure refuse les écritures SIMULTANÉES d'identifiants sur une même identité : le second attend le premier.
resource "azurerm_federated_identity_credential" "plan_main" {
  name                = "github-main"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.plan.id
  audience            = local.audience
  issuer              = local.issuer
  subject             = local.plan_subjects["main"]

  depends_on = [azurerm_federated_identity_credential.plan_pr]
}

resource "azurerm_role_assignment" "plan_reader" {
  for_each = azurerm_resource_group.target

  scope                = each.value.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

# EN: Plan must take the state LEASE (lock), which is a write. / FR : Plan doit prendre le BAIL (verrou) de l'état, ce qui est une écriture.
resource "azurerm_role_assignment" "plan_state" {
  scope                = local.state_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

# ----------------------------------------------------------------------- apply
resource "azurerm_user_assigned_identity" "apply" {
  for_each = var.environments

  name                = "id-tf-gha-apply-${each.key}"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "apply" {
  for_each = var.environments

  name                = "github-environment-${each.key}"
  resource_group_name = azurerm_resource_group.identity.name
  parent_id           = azurerm_user_assigned_identity.apply[each.key].id
  audience            = local.audience
  issuer              = local.issuer
  subject             = "repo:${var.github_repo}:environment:${each.key}"
}

resource "azurerm_role_assignment" "apply_contributor" {
  for_each = var.environments

  scope                = azurerm_resource_group.target[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_state" {
  for_each = var.environments

  scope                = local.state_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.apply[each.key].principal_id
  principal_type       = "ServicePrincipal"
}
