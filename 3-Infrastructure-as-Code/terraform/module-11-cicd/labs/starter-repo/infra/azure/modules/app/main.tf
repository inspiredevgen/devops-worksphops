# =============================================================================
# The small app deployed by the pipeline: a hardened storage account in a PRE-CREATED resource group.
# La petite application déployée par le pipeline : un compte de stockage renforcé dans un groupe de ressources CRÉÉ À L'AVANCE.
# EN: The apply identity is Contributor on rg-tf-cicd-<environment> ONLY, so it reads the RG instead of creating it.
# FR : L'identité apply n'est Contributor QUE sur rg-tf-cicd-<environment> : elle lit le RG au lieu de le créer.
# =============================================================================

data "azurerm_resource_group" "this" {
  name = "rg-tf-cicd-${var.environment}"
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "this" {
  name                            = "sttfcicd${var.environment}${random_string.suffix.result}"
  resource_group_name             = data.azurerm_resource_group.this.name
  location                        = data.azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  tags                            = var.tags

  blob_properties {
    versioning_enabled = true
  }
}
