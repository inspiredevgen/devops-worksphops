# =============================================================================
# Lab 8.B-AZ — A three-tier VNet with NSGs that really isolate the tiers
# Lab 8.B-AZ — Un VNet à trois niveaux avec des NSG qui isolent vraiment les niveaux
# =============================================================================

locals {
  name    = "tf-lab-m08"
  subnets = { for tier, n in var.tiers : tier => cidrsubnet(var.vnet_cidr, 8, n) }

  # EN: Who may talk to whom: web ← Internet:443, app ← web:8080, data ← app:5432.
  # FR : Qui parle à qui : web ← Internet:443, app ← web:8080, data ← app:5432.
  allow_rules = {
    web  = { source = "Internet", port = "443" }
    app  = { source = local.subnets["web"], port = "8080" }
    data = { source = local.subnets["app"], port = "5432" }
  }
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "08-networking"
    ManagedBy = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}-net"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "tier" {
  for_each = local.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]
}

resource "azurerm_network_security_group" "tier" {
  for_each = local.subnets

  name                = "nsg-${local.name}-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "allow-${each.key}-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = local.allow_rules[each.key].port
    source_address_prefix      = local.allow_rules[each.key].source
    destination_address_prefix = each.value
  }

  # EN: WHY THIS RULE? Azure's built-in rule 65000 "AllowVnetInBound" lets EVERY subnet
  #     talk to every other one. Without this deny, "web" could reach "data" directly.
  # FR : POURQUOI CETTE RÈGLE ? La règle intégrée 65000 « AllowVnetInBound » laisse CHAQUE
  #     sous-réseau parler à tous les autres. Sans ce refus, « web » pourrait joindre « data » directement.
  security_rule {
    name                       = "deny-vnet-in"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "tier" {
  for_each = azurerm_subnet.tier

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.tier[each.key].id
}

output "address_plan" {
  value = local.subnets
}

output "free_addresses_per_subnet" {
  description = "EN: Azure reserves 5 IPs per subnet / FR: Azure réserve 5 IP par sous-réseau"
  value       = { for k, c in local.subnets : k => pow(2, 32 - tonumber(split("/", c)[1])) - 5 }
}
