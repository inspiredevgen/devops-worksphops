# -----------------------------------------------------------------------------
# Lab 5.I-AZ — for_each over maps, filters, grouping and flatten
# Lab 5.I-AZ — for_each sur des maps, filtres, regroupements et flatten
#
# EN: Cost: $0 (VNet, subnets, NSGs, managed identities are free).
# FR: Coût : 0 $ (VNet, sous-réseaux, NSG, identités managées gratuits).
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m05-foreach"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-tf-lab-m05"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

# EN: for_each over a MAP → each.key = "web", each.value = { netnum, nsg, service_endpoints }
#     Address: azurerm_subnet.this["web"]
# FR: for_each sur une MAP → each.key = « web », each.value = { netnum, nsg, service_endpoints }
#     Adresse : azurerm_subnet.this["web"]
resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.key == "GatewaySubnet" ? each.key : "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, each.value.netnum)]
  service_endpoints    = each.value.service_endpoints
}

# EN: for_each over the FILTERED map → no NSG for GatewaySubnet.
# FR: for_each sur la map FILTRÉE → pas de NSG pour GatewaySubnet.
resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_subnets

  name                = "nsg-tf-lab-m05-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# EN: The flattened LIST → a MAP keyed by "team-env" for for_each.
# FR: La LISTE aplatie → une MAP indexée par « équipe-env » pour for_each.
resource "azurerm_user_assigned_identity" "team" {
  for_each = { for te in local.team_envs : te.key => te }

  name                = "id-tf-lab-m05-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  tags = merge(local.tags, {
    team        = each.value.team
    environment = each.value.env
  })
}
