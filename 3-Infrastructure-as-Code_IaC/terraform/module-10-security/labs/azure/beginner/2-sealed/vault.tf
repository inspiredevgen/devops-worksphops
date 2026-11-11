terraform {
  required_version = ">= 1.11.0, < 2.0.0" # EN: write-only arguments / FR : arguments en écriture seule

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.34.0, < 5.0.0" # EN: value_wo on key vault secrets / FR : value_wo sur les secrets Key Vault
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

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

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-tf-lab-m10-sealed"
  location = var.location
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "10-security"
    ManagedBy = "terraform"
  }
}

# EN: Lab vault: public endpoint so your laptop can reach it. In production: private endpoint
#     (Module 8), purge protection on, and Azure RBAC instead of access policies.
# FR : Coffre de lab : point de terminaison public pour que votre portable l'atteigne. En production :
#     point de terminaison privé (module 8), protection contre la purge, et Azure RBAC plutôt que des stratégies d'accès.
resource "azurerm_key_vault" "this" {
  name                       = "kvtfm10sealed${random_string.suffix.result}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # EN: lab only, so destroy can purge / FR : lab seulement, pour que destroy puisse purger
  tags                       = azurerm_resource_group.this.tags

  # EN: The identity running Terraform may manage secrets (Purge lets destroy clean up fully).
  # FR : L'identité qui exécute Terraform peut gérer les secrets (Purge permet à destroy de tout nettoyer).
  access_policy {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    object_id          = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
  }
}
