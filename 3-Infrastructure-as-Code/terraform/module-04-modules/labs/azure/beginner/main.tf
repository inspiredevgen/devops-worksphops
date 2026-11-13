# -----------------------------------------------------------------------------
# Lab 4.B-AZ — Consuming an Azure Verified Module (AVM)
# Lab 4.B-AZ — Utiliser un Azure Verified Module (AVM)
#
# EN: AVM = Microsoft's official, supported module library. This one creates
#     a VNet and its subnets. Cost: $0 (VNets and subnets are free).
# FR: AVM = la bibliothèque officielle de modules de Microsoft. Celui-ci crée
#     un VNet et ses sous-réseaux. Coût : 0 $ (VNet et sous-réseaux gratuits).
# -----------------------------------------------------------------------------

variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m04-avm"
  location = var.location

  tags = {
    course = "terraform-cloud-engineer"
    module = "04-modules"
  }
}

module "vnet" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm"

  # EN: AVM modules are still 0.x → pin tightly: "~> 0.22.0" allows 0.22.x only.
  #     In 0.x, even a minor bump (0.22 → 0.23) may contain breaking changes.
  # FR: Les modules AVM sont encore en 0.x → épinglez serré : « ~> 0.22.0 »
  #     n'autorise que 0.22.x. En 0.x, même une version mineure peut casser.
  version = "~> 0.22.0"

  name          = "vnet-tf-lab-m04-avm"
  location      = azurerm_resource_group.lab.location
  parent_id     = azurerm_resource_group.lab.id # EN: since v0.11 (was resource_group_name) / FR: depuis v0.11
  address_space = ["10.70.0.0/16"]

  subnets = {
    web = {
      name             = "snet-web"
      address_prefixes = ["10.70.1.0/24"]
    }
    app = {
      name             = "snet-app"
      address_prefixes = ["10.70.2.0/24"]
    }
  }

  # EN: AVM sends anonymous usage telemetry by default; we turn it off.
  # FR: AVM envoie par défaut une télémétrie anonyme ; nous la désactivons.
  enable_telemetry = false

  tags = azurerm_resource_group.lab.tags
}

# EN: Consuming module OUTPUTS in a root resource.
# FR: Utiliser les SORTIES du module dans une ressource racine.
resource "azurerm_network_security_group" "web" {
  name                = "nsg-tf-lab-m04-web"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = module.vnet.subnets["web"].resource_id
  network_security_group_id = azurerm_network_security_group.web.id
}
