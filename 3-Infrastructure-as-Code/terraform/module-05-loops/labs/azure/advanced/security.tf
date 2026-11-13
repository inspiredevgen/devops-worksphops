# -----------------------------------------------------------------------------
# Lab 5.A-AZ (part 1) — One NSG whose rules are generated from data
# Lab 5.A-AZ (partie 1) — Un NSG dont les règles sont générées à partir de données
#
# EN: Here we DO use a dynamic block: all rules live in one NSG, and they
#     reference ASGs (separate resources) → no dependency cycle.
#     Cost: $0 (NSGs, ASGs, VNets are free).
# FR: Ici, nous UTILISONS un bloc dynamic : toutes les règles sont dans un seul
#     NSG, et elles référencent des ASG (ressources séparées) → aucun cycle.
#     Coût : 0 $ (NSG, ASG, VNet gratuits).
# -----------------------------------------------------------------------------

locals {
  tags = {
    course = "terraform-cloud-engineer"
    module = "05-loops"
  }

  # EN: 1) Flatten in a DETERMINISTIC order (sorted tiers, then rule order).
  # FR: 1) Aplatir dans un ordre DÉTERMINISTE (niveaux triés, puis ordre des règles).
  flat_rules = flatten([
    for tier in sort(keys(var.tiers)) : [
      for r in var.tiers[tier] : merge(r, { tier = tier })
    ]
  ])

  # EN: 2) Compute priorities from the position: 100, 110, 120…
  #        ⚠️ Inserting a rule renumbers the ones after it (an in-place
  #        update of the NSG — acceptable here, but know why it happens).
  # FR: 2) Calculer les priorités à partir de la position : 100, 110, 120…
  #        ⚠️ Insérer une règle renumérote les suivantes (mise à jour sur place
  #        du NSG — acceptable ici, mais sachez pourquoi).
  nsg_rules = [
    for i, r in local.flat_rules : merge(r, { priority = 100 + i * 10 })
  ]
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m05-dynamic"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-tf-lab-m05-dynamic"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.84.0.0/16"]
}

resource "azurerm_subnet" "workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.84.1.0/24"]
}

# EN: One ASG per tier — VMs/NICs would join these groups.
# FR: Un ASG par niveau — les VM/cartes réseau rejoindraient ces groupes.
resource "azurerm_application_security_group" "tier" {
  for_each = var.tiers

  name                = "asg-tf-lab-m05-${each.key}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-tf-lab-m05-workload"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags

  # EN: GENERATED rules. `security_rule` is the iterator name by default.
  # FR: Règles GÉNÉRÉES. `security_rule` est le nom d'itérateur par défaut.
  dynamic "security_rule" {
    for_each = local.nsg_rules

    content {
      name                   = "${security_rule.value.tier}-${security_rule.value.name}"
      priority               = security_rule.value.priority
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = security_rule.value.protocol
      source_port_range      = "*"
      destination_port_range = tostring(security_rule.value.port)
      source_address_prefix  = try(coalesce(security_rule.value.source_cidr, security_rule.value.source_tag), null)
      source_application_security_group_ids = security_rule.value.source_tier == null ? null : [
        azurerm_application_security_group.tier[security_rule.value.source_tier].id
      ]
      destination_application_security_group_ids = [
        azurerm_application_security_group.tier[security_rule.value.tier].id
      ]
    }
  }

  # EN: A STATIC block next to the dynamic ones: explicit deny of all other
  #     inbound traffic (overrides Azure's default AllowVnetInBound at 65000).
  # FR: Un bloc STATIQUE à côté des blocs dynamiques : refus explicite de tout
  #     autre trafic entrant (prime sur AllowVnetInBound par défaut, à 65000).
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
