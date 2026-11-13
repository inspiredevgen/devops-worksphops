# -----------------------------------------------------------------------------
# EN: Network module: VNet + one subnet per name + one NSG per subnet
#     (secure by default). `for_each` is a preview of Module 5.
# FR: Module réseau : VNet + un sous-réseau par nom + un NSG par sous-réseau
#     (sécurisé par défaut). `for_each` est un aperçu du module 5.
# -----------------------------------------------------------------------------

locals {
  # EN: { "app" = "10.80.0.0/24", "data" = "10.80.1.0/24", ... }
  # FR: { "app" = "10.80.0.0/24", "data" = "10.80.1.0/24", ... }
  subnets = { for i, n in var.subnet_names : n => cidrsubnet(var.address_space, 8, i) }
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]

  # EN: v1.1.0 — free; lets PaaS services (e.g. Storage) trust this subnet.
  # FR: v1.1.0 — gratuit ; permet aux services PaaS (ex. Storage) de faire confiance à ce sous-réseau.
  service_endpoints = var.service_endpoints
}

resource "azurerm_network_security_group" "this" {
  for_each = local.subnets

  name                = "nsg-${var.name}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
