# -----------------------------------------------------------------------------
# Lab 4.I-AZ — Writing and reusing your own module
# Lab 4.I-AZ — Écrire et réutiliser votre propre module
#
# EN: The SAME module, called twice with different inputs. Cost: $0.
# FR: Le MÊME module, appelé deux fois avec des entrées différentes. Coût : 0 $.
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

locals {
  tags = {
    course = "terraform-cloud-engineer"
    module = "04-modules"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m04-own"
  location = var.location
  tags     = local.tags
}

module "app_network" {
  source = "./modules/network" # EN: LOCAL path — no version / FR: chemin LOCAL — pas de version

  name                = "tf-lab-m04-app"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = "10.80.0.0/16"
  subnet_names        = ["web", "app", "data"]
  tags                = merge(local.tags, { network = "app" })
}

module "shared_network" {
  source = "./modules/network"

  name                = "tf-lab-m04-shared"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = "10.81.0.0/20"
  subnet_names        = ["mgmt"]
  tags                = merge(local.tags, { network = "shared" })
}
