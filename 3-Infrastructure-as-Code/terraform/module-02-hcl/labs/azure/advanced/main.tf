# -----------------------------------------------------------------------------
# Lab 2.A-AZ — Complex types, function chains and templatefile()
# Lab 2.A-AZ — Types complexes, chaînes de fonctions et templatefile()
#
# EN: A VNet with 2 subnets computed by functions, plus a configuration file
#     RENDERED from a template and stored as a blob. Cost: ~$0 (VNets and
#     subnets are free; tiny blob).
# FR: Un VNet avec 2 sous-réseaux calculés par des fonctions, et un fichier de
#     configuration GÉNÉRÉ depuis un modèle et stocké comme blob. Coût : ~0 $
#     (VNet et sous-réseaux gratuits ; blob minuscule).
# -----------------------------------------------------------------------------

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

resource "azurerm_virtual_network" "app" {
  name                = "vnet-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  address_space       = [var.vnet_cidr]
  tags                = local.common_tags
}

resource "azurerm_subnet" "public" {
  name                 = "snet-public"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = [local.subnet_cidrs["public"]]
}

resource "azurerm_subnet" "private" {
  name                 = "snet-private"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = [local.subnet_cidrs["private"]]
}

resource "azurerm_storage_account" "config" {
  name                = local.storage_account_name
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location

  account_tier             = "Standard"
  account_replication_type = local.replication

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = local.common_tags
}

resource "azurerm_storage_container" "config" {
  name                  = "config"
  storage_account_id    = azurerm_storage_account.config.id
  container_access_type = "private"
}

# EN: The rendered template becomes a blob. NOTE: in AzureRM, changing
#     source_content REPLACES the blob (-/+), unlike S3 objects (~).
# FR: Le modèle généré devient un blob. NOTE : avec AzureRM, modifier
#     source_content REMPLACE le blob (-/+), contrairement aux objets S3 (~).
resource "azurerm_storage_blob" "app_config" {
  name                 = "${var.app.environment}/app-config.yaml"
  storage_container_id = azurerm_storage_container.config.id
  type                 = "Block"
  source_content       = local.rendered_config
  content_type         = "application/yaml"
}
