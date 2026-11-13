# -----------------------------------------------------------------------------
# EN: app-stack — the SAME building block deployed in every environment.
#     Environments differ only by INPUTS, never by code.
# FR: app-stack — la MÊME brique déployée dans chaque environnement.
#     Les environnements ne diffèrent que par les ENTRÉES, jamais par le code.
# -----------------------------------------------------------------------------

locals {
  name = "${var.app_name}-${var.environment}"
  tags = merge(var.tags, {
    app         = var.app_name
    environment = var.environment
    course      = "terraform-cloud-engineer"
    module      = "06-environments"
  })
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "data" {
  # EN: e.g. "st" + "tflabm06" + "staging" + 5 chars = 22 (≤ 24)
  # FR: ex. « st » + « tflabm06 » + « staging » + 5 caractères = 22 (≤ 24)
  name                = "st${var.app_name}${var.environment}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location

  account_tier                    = "Standard"
  account_replication_type        = var.replication
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    delete_retention_policy {
      days = var.soft_delete_days
    }
  }

  tags = local.tags
}

resource "azurerm_log_analytics_workspace" "app" {
  name                = "log-${local.name}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}
