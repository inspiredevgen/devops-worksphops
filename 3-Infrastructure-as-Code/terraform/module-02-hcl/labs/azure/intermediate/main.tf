# -----------------------------------------------------------------------------
# Lab 2.I-AZ — One configuration, many environments
# Lab 2.I-AZ — Une configuration, plusieurs environnements
#
# EN: Same code, different settings per environment, driven by *.tfvars,
#     locals and functions. Cost: ~$0 (empty storage; Log Analytics bills per
#     GB ingested — nothing is sent here).
# FR: Même code, paramètres différents selon l'environnement, grâce aux
#     *.tfvars, locals et fonctions. Coût : ~0 $ (stockage vide ; Log Analytics
#     facture par Go ingéré — rien n'est envoyé ici).
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "app" {
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location

  account_tier             = "Standard"
  account_replication_type = local.settings.replication

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # EN: Conditional: keep deleted blobs longer in prod.
  # FR: Conditionnelle : conserver plus longtemps les blobs supprimés en prod.
  blob_properties {
    delete_retention_policy {
      days = var.environment == "prod" ? 30 : 7
    }
  }

  tags = local.common_tags
}

resource "azurerm_log_analytics_workspace" "app" {
  name                = "log-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  sku                 = "PerGB2018"
  retention_in_days   = local.log_retention_days
  tags                = local.common_tags
}
