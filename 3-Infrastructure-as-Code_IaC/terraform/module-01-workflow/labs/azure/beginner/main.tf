# -----------------------------------------------------------------------------
# Lab 1.B-AZ — Your first managed resources: resource group + storage account
# Lab 1.B-AZ — Vos premières ressources gérées : groupe de ressources + compte de stockage
#
# EN: Walk through the full workflow: init → fmt → validate → plan → apply →
#     inspect → destroy. Cost: ~$0 (empty Standard LRS account).
# FR: Parcourez tout le cycle : init → fmt → validate → plan → apply →
#     inspection → destroy. Coût : ~0 $ (compte Standard LRS vide).
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

locals {
  tags = {
    course    = "terraform-cloud-engineer"
    module    = "01-workflow"
    managedBy = "terraform"
  }
}

# EN: Storage account names are GLOBALLY unique, 3-24 chars, lowercase letters
#     and digits only. A random suffix avoids collisions.
# FR: Les noms de comptes de stockage sont UNIQUES MONDIALEMENT, 3 à 24 caractères,
#     minuscules et chiffres uniquement. Un suffixe aléatoire évite les collisions.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# EN: Every Azure resource lives in a resource group.
# FR: Toute ressource Azure réside dans un groupe de ressources.
resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m01"
  location = var.location
  tags     = local.tags
}

# EN: Referencing azurerm_resource_group.lab.name creates an IMPLICIT dependency:
#     Terraform creates the resource group first.
# FR: Référencer azurerm_resource_group.lab.name crée une dépendance IMPLICITE :
#     Terraform crée d'abord le groupe de ressources.
resource "azurerm_storage_account" "lab" {
  name                = "sttflabm01${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  account_tier             = "Standard"
  account_replication_type = "LRS" # EN: cheapest / FR: le moins cher

  # EN: Secure defaults, declared explicitly.
  # FR: Paramètres sécurisés, déclarés explicitement.
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = local.tags
}

# EN: storage_account_id makes the provider use the management (ARM) API,
#     so the Contributor role from Module 0 is enough.
# FR: storage_account_id fait passer le provider par l'API de gestion (ARM) :
#     le rôle Contributeur du module 0 suffit.
resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.lab.id
  container_access_type = "private"
}
