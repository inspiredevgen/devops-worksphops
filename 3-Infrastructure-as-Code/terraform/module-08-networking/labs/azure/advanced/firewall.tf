# =============================================================================
# Part 3 (optional, ~$0.40/hour): Azure Firewall Basic as the hub's router
# Partie 3 (facultative, ~0,40 $/heure) : Azure Firewall Basic comme routeur du hub
# =============================================================================

resource "azurerm_public_ip" "fw" {
  for_each = var.enable_firewall ? toset(["data", "mgmt"]) : toset([])

  name                = "pip-${local.name}-fw-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall_policy" "this" {
  count = var.enable_firewall ? 1 : 0

  name                = "afwp-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
  tags                = local.tags
}

# EN: Explicit allow-list between spokes: app → data on 5432 only, plus ping for testing.
# FR : Liste d'autorisations explicite entre rayons : app → data sur 5432 seulement, plus le ping pour tester.
resource "azurerm_firewall_policy_rule_collection_group" "spokes" {
  count = var.enable_firewall ? 1 : 0

  name               = "spoke-to-spoke"
  firewall_policy_id = azurerm_firewall_policy.this[0].id
  priority           = 200

  network_rule_collection {
    name     = "allow-app-to-data"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "postgres"
      protocols             = ["TCP"]
      source_addresses      = [var.spokes["app"]]
      destination_addresses = [var.spokes["data"]]
      destination_ports     = ["5432"]
    }

    rule {
      name                  = "icmp-test"
      protocols             = ["ICMP"]
      source_addresses      = values(var.spokes)
      destination_addresses = values(var.spokes)
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_firewall" "this" {
  count = var.enable_firewall ? 1 : 0

  name                = "afw-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  tags                = local.tags

  ip_configuration {
    name                 = "data"
    subnet_id            = azurerm_subnet.hub["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.fw["data"].id
  }

  # EN: The Basic tier always needs a separate management subnet + IP.
  # FR : Le niveau Basic exige toujours un sous-réseau et une IP de gestion séparés.
  management_ip_configuration {
    name                 = "mgmt"
    subnet_id            = azurerm_subnet.hub["AzureFirewallManagementSubnet"].id
    public_ip_address_id = azurerm_public_ip.fw["mgmt"].id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.spokes]
}

# EN: User-defined routes (UDRs): "to reach the OTHER spokes, go via the firewall".
# FR : Routes définies par l'utilisateur (UDR) : « pour joindre les AUTRES rayons, passez par le pare-feu ».
resource "azurerm_route_table" "spoke" {
  for_each = var.enable_firewall ? var.spokes : {}

  name                = "rt-tf-lab-m08-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  dynamic "route" {
    for_each = { for k, cidr in var.spokes : k => cidr if k != each.key }
    content {
      name                   = "to-${route.key}-via-fw"
      address_prefix         = route.value
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = azurerm_firewall.this[0].ip_configuration[0].private_ip_address
    }
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = var.enable_firewall ? var.spokes : {}

  subnet_id      = azurerm_subnet.spoke["${each.key}/workload"].id
  route_table_id = azurerm_route_table.spoke[each.key].id
}

output "firewall_private_ip" {
  value = var.enable_firewall ? azurerm_firewall.this[0].ip_configuration[0].private_ip_address : null
}
