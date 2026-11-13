# -----------------------------------------------------------------------------
# Lab 1.I-AZ — Reading plans like a pro: update, replace, -replace, -target, drift
# Lab 1.I-AZ — Lire un plan comme un pro : update, replace, -replace, -target, dérive
#
# EN: Change ONE variable at a time and predict the plan BEFORE running it.
# FR: Changez UNE variable à la fois et prédisez le plan AVANT de l'exécuter.
# -----------------------------------------------------------------------------

locals {
  tags = {
    course      = "terraform-cloud-engineer"
    module      = "01-workflow"
    managedBy   = "terraform"
    environment = var.environment
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m01-int"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "lab" {
  name                = "sttfm01int${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  account_tier             = "Standard"
  account_replication_type = var.replication_type

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = local.tags
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.lab.id
  container_access_type = "private"
}

# EN: A small text blob. Its content comes from a variable.
#     storage_container_id replaces the older storage_account_name +
#     storage_container_name pair (deprecated in AzureRM 4.77).
# FR: Un petit blob texte. Son contenu provient d'une variable.
#     storage_container_id remplace l'ancienne paire storage_account_name +
#     storage_container_name (dépréciée dans AzureRM 4.77).
resource "azurerm_storage_blob" "readme" {
  name                 = "README.txt"
  storage_container_id = azurerm_storage_container.data.id
  type                 = "Block"
  source_content       = var.welcome_message
  content_type         = "text/plain"
}
