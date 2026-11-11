# -----------------------------------------------------------------------------
# Lab 1.A-AZ — Controlling the resource lifecycle
# Lab 1.A-AZ — Contrôler le cycle de vie des ressources
#
# EN: Four `lifecycle` techniques used in production:
#       1. create_before_destroy  → rotate a managed identity without a gap
#       2. ignore_changes         → tolerate a tag added by Azure Policy / FinOps
#       3. replace_triggered_by   → recreate a container on each release
#       4. prevent_destroy        → protect the storage account
#     Cost: ~$0 (identities are free; empty Standard LRS storage).
# FR: Quatre techniques `lifecycle` utilisées en production :
#       1. create_before_destroy  → faire tourner une identité managée sans interruption
#       2. ignore_changes         → tolérer une étiquette ajoutée par Azure Policy / FinOps
#       3. replace_triggered_by   → recréer un conteneur à chaque version
#       4. prevent_destroy        → protéger le compte de stockage
#     Coût : ~0 $ (identités gratuites ; stockage Standard LRS vide).
# -----------------------------------------------------------------------------

locals {
  tags = {
    course    = "terraform-cloud-engineer"
    module    = "01-workflow"
    managedBy = "terraform"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m01-adv"
  location = var.location
  tags     = local.tags
}

# =============================================================================
# 1. create_before_destroy
# =============================================================================
# EN: `keepers`: when any value changes, random_pet generates a NEW name.
# FR: `keepers` : quand une valeur change, random_pet génère un NOUVEAU nom.
resource "random_pet" "identity" {
  length = 2
  keepers = {
    generation = var.identity_generation
  }
}

# EN: A new name forces replacement. With create_before_destroy, the new
#     identity exists BEFORE the old one is deleted — consumers can switch over.
#     Terraform automatically applies create_before_destroy to random_pet too.
# FR: Un nouveau nom force le remplacement. Avec create_before_destroy, la
#     nouvelle identité existe AVANT la suppression de l'ancienne — les
#     consommateurs peuvent basculer. Terraform applique aussi automatiquement
#     create_before_destroy à random_pet.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-tf-lab-${random_pet.identity.id}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# 2 + 4. ignore_changes (one tag key) + prevent_destroy
# =============================================================================
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "critical" {
  name                = "sttfm01adv${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = local.tags

  lifecycle {
    # EN: Any plan that would destroy this account fails. Literal values only.
    # FR: Tout plan qui détruirait ce compte échoue. Valeurs littérales uniquement.
    prevent_destroy = true

    # EN: Ignore ONLY the "costCenter" tag (often added by Azure Policy).
    #     Any other manual tag change is still detected and reverted.
    # FR: Ignorer UNIQUEMENT l'étiquette « costCenter » (souvent ajoutée par
    #     Azure Policy). Tout autre changement manuel reste détecté et annulé.
    ignore_changes = [tags["costCenter"]]
  }
}

# =============================================================================
# 3. replace_triggered_by
# =============================================================================
resource "terraform_data" "release" {
  input = var.release_version
}

# EN: Recreated (emptied) on every new release.
# FR: Recréé (vidé) à chaque nouvelle version.
resource "azurerm_storage_container" "release_current" {
  name                  = "release-current"
  storage_account_id    = azurerm_storage_account.critical.id
  container_access_type = "private"

  lifecycle {
    replace_triggered_by = [terraform_data.release]
  }
}
