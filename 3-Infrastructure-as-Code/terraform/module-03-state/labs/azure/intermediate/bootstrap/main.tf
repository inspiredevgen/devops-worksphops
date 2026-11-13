# -----------------------------------------------------------------------------
# Lab 3.I-AZ (part 1) — A production-grade storage account for Terraform state
# Lab 3.I-AZ (partie 1) — Un compte de stockage de qualité production pour l'état Terraform
#
# EN: Blob versioning + soft delete (recovery), TLS 1.2, no public access,
#     prevent_destroy. Locking is automatic: the backend takes a BLOB LEASE.
#     Cost: a few cents per month at most.
# FR: Versionnage des blobs + suppression réversible (récupération), TLS 1.2,
#     aucun accès public, prevent_destroy. Le verrouillage est automatique :
#     le backend prend un BAIL (lease) sur le blob.
#     Coût : quelques cents par mois au maximum.
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate-lab"
  location = var.location

  tags = {
    course  = "terraform-cloud-engineer"
    module  = "03-state"
    purpose = "terraform-state"
  }
}

resource "azurerm_storage_account" "state" {
  name                = "sttfstate${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_tier             = "Standard"
  account_replication_type = "LRS" # EN: GRS/ZRS in production / FR: GRS/ZRS en production

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    # EN: Every state write creates a new blob version → roll back possible.
    # FR: Chaque écriture d'état crée une nouvelle version de blob → retour arrière possible.
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = azurerm_resource_group.state.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
