# -----------------------------------------------------------------------------
# Lab 6.B-AZ — One configuration, several CLI workspaces
# Lab 6.B-AZ — Une configuration, plusieurs workspaces CLI
#
# EN: Cost: $0 (resource group + empty storage account).
# FR: Coût : 0 $ (groupe de ressources + compte de stockage vide).
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
  # EN: Allowed workspaces and their settings. "default" is NOT allowed.
  # FR: Workspaces autorisés et leurs paramètres. « default » n'est PAS autorisé.
  env_settings = {
    dev = {
      replication = "LRS"
      soft_delete = 7
    }
    prod = {
      replication = "GRS"
      soft_delete = 30
    }
  }

  env      = terraform.workspace
  settings = lookup(local.env_settings, local.env, local.env_settings["dev"])
}

# EN: GUARD — fail fast in an unknown workspace (e.g. "default").
# FR: GARDE — échouer vite dans un workspace inconnu (ex. « default »).
resource "terraform_data" "workspace_guard" {
  input = local.env

  lifecycle {
    precondition {
      condition     = contains(keys(local.env_settings), local.env)
      error_message = "EN: Workspace '${local.env}' is not allowed. Run: terraform workspace select dev (or prod). / FR : Le workspace « ${local.env} » n'est pas autorisé. Lancez : terraform workspace select dev (ou prod)."
    }
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "app" {
  name     = "rg-tf-lab-m06-${local.env}"
  location = var.location

  tags = {
    course      = "terraform-cloud-engineer"
    module      = "06-environments"
    environment = local.env
  }

  depends_on = [terraform_data.workspace_guard]
}

resource "azurerm_storage_account" "app" {
  name                = "sttfm06${local.env}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location

  account_tier                    = "Standard"
  account_replication_type        = local.settings.replication
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    delete_retention_policy {
      days = local.settings.soft_delete
    }
  }

  tags = azurerm_resource_group.app.tags
}

output "workspace" {
  description = "EN: Current workspace / FR: Workspace actuel"
  value       = terraform.workspace
}

output "storage_account_name" {
  description = "EN: Storage account for this workspace / FR: Compte de stockage de ce workspace"
  value       = azurerm_storage_account.app.name
}
