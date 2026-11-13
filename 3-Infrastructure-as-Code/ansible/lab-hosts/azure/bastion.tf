# =============================================================================
# bastion mode only: Azure Bastion Standard with native-client TUNNELS (no public IP on any VM).
# Mode bastion seulement : Azure Bastion Standard avec TUNNELS client natif (aucune IP publique sur les VM).
# =============================================================================

resource "azurerm_subnet" "bastion" {
  count = local.ssh ? 0 : 1

  name                 = "AzureBastionSubnet" # EN: exact name required / FR : nom exact obligatoire
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.140.0.0/26"]
}

resource "azurerm_public_ip" "bastion" {
  count = local.ssh ? 0 : 1

  name                = "pip-ans-lab-bastion"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_bastion_host" "lab" {
  count = local.ssh ? 0 : 1

  name                = "bas-ans-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "Standard"
  tunneling_enabled   = true # EN: `az network bastion tunnel` needs this / FR : `az network bastion tunnel` l'exige
  tags                = local.tags

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}
