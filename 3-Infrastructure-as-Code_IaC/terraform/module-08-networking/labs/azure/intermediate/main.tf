# =============================================================================
# Lab 8.I-AZ — One module, two regions, global VNet peering
# Lab 8.I-AZ — Un module, deux régions, appairage VNet mondial
# =============================================================================

locals {
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "08-networking"
    ManagedBy = "terraform"
  }

  # EN: Same overlap test as the AWS lab: CIDR → integer range [start, start + size).
  # FR : Même test de chevauchement que le lab AWS : CIDR → plage d'entiers [début, début + taille).
  ranges = {
    for k, c in { primary = var.primary_cidr, secondary = var.secondary_cidr } : k => {
      start               = sum([for i, octet in split(".", cidrhost(c, 0)) : tonumber(octet) * pow(256, 3 - i)])
      size                = pow(2, 32 - tonumber(split("/", c)[1]))
    }
  }
  cidrs_overlap = (
    local.ranges.primary.start < local.ranges.secondary.start + local.ranges.secondary.size &&
    local.ranges.secondary.start < local.ranges.primary.start + local.ranges.primary.size
  )
}

module "primary" {
  source = "./modules/network"

  name     = "primary"
  location = var.primary_location
  cidr     = var.primary_cidr
  tags     = local.tags
}

module "secondary" {
  source = "./modules/network"

  name     = "secondary"
  location = var.secondary_location # EN: the region change / FR : le changement de région
  cidr     = var.secondary_cidr
  tags     = local.tags

  providers = {
    azurerm = azurerm.secondary # EN: the subscription change / FR : le changement d'abonnement
  }
}

# EN: Azure peering is TWO resources: one link on each VNet. Both must exist to be "Connected".
# FR : L'appairage Azure, c'est DEUX ressources : un lien sur chaque VNet. Les deux doivent exister pour être « Connected ».
resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  name                      = "peer-primary-to-secondary"
  resource_group_name       = module.primary.resource_group_name
  virtual_network_name      = module.primary.vnet_name
  remote_virtual_network_id = module.secondary.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false

  lifecycle {
    precondition {
      condition     = !local.cidrs_overlap
      error_message = "EN: ${var.primary_cidr} and ${var.secondary_cidr} overlap; peering would fail. / FR : ${var.primary_cidr} et ${var.secondary_cidr} se chevauchent ; l'appairage échouerait."
    }
  }
}

resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  provider = azurerm.secondary

  name                      = "peer-secondary-to-primary"
  resource_group_name       = module.secondary.resource_group_name
  virtual_network_name      = module.secondary.vnet_name
  remote_virtual_network_id = module.primary.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

output "networks" {
  value = {
    primary   = { location = var.primary_location, vnet = module.primary.vnet_name, cidr = var.primary_cidr }
    secondary = { location = var.secondary_location, vnet = module.secondary.vnet_name, cidr = var.secondary_cidr }
  }
}

output "check_peering" {
  value = "az network vnet peering list -g ${module.primary.resource_group_name} --vnet-name ${module.primary.vnet_name} --query '[].{name:name, state:peeringState, sync:peeringSyncLevel}' -o table"
}
