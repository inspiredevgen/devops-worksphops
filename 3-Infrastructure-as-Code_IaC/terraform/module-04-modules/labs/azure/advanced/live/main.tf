# -----------------------------------------------------------------------------
# Lab 4.A-AZ — Composition with a VERSIONED module from Git
# Lab 4.A-AZ — Composition avec un module VERSIONNÉ depuis Git
#
# EN: STARTING POINT (network v1.0.0). The guide walks you through v1.1.0
#     (service endpoints) and v2.0.0 (breaking change). Final version:
#     ../solution/main.tf.v2.solution. Cost: $0.
# FR: POINT DE DÉPART (network v1.0.0). Le guide vous accompagne vers la
#     v1.1.0 (points de terminaison de service) et la v2.0.0 (changement
#     incompatible). Version finale : ../solution/main.tf.v2.solution. Coût : 0 $.
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

# EN: Your public IP, so YOU can still reach the storage account once it is
#     locked to the VNet (find it with: curl -s https://api.ipify.org).
# FR: Votre IP publique, pour que VOUS puissiez encore joindre le compte de
#     stockage une fois limité au VNet (trouvez-la avec : curl -s https://api.ipify.org).
variable "my_ip" {
  description = "EN: Your public IPv4 address (no /32) / FR: Votre adresse IPv4 publique (sans /32)"
  type        = string
  default     = null

  validation {
    condition     = var.my_ip == null || can(regex("^\\d{1,3}(\\.\\d{1,3}){3}$", coalesce(var.my_ip, "0.0.0.0")))
    error_message = "EN: Plain IPv4 address, e.g. 203.0.113.10. / FR : Adresse IPv4 simple, ex. 203.0.113.10."
  }
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-tf-lab-m04-platform"
  location = var.location

  tags = {
    course = "terraform-cloud-engineer"
    module = "04-modules"
  }
}

# EN: FLAT COMPOSITION — the root wires module outputs into module inputs.
# FR: COMPOSITION À PLAT — la racine relie les sorties aux entrées des modules.

module "network" {
  # EN: Replace <YOUR-GITHUB-USER>, or use a local repo:
  #       source = "git::file:///ABSOLUTE/PATH/terraform-azurerm-network?ref=v1.0.0"
  # FR: Remplacez <YOUR-GITHUB-USER>, ou utilisez un dépôt local :
  #       source = "git::file:///CHEMIN/ABSOLU/terraform-azurerm-network?ref=v1.0.0"
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-azurerm-network.git?ref=v1.0.0"

  name                = "tf-lab-m04-platform"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  address_space       = "10.82.0.0/16"
  subnet_names        = ["app", "data"]
}

module "data_storage" {
  source = "./modules/private-storage"

  name_prefix         = "tflabm04data"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  # EN: v1.0.0 subnets have no Microsoft.Storage endpoint yet → open access.
  # FR: Les sous-réseaux v1.0.0 n'ont pas encore le point Microsoft.Storage → accès ouvert.
  allowed_subnet_ids = []
}

output "subnet_ids" {
  description = "EN: Subnet IDs / FR: ID des sous-réseaux"
  value       = module.network.subnet_ids
}

output "storage_account_name" {
  description = "EN: Data storage account / FR: Compte de stockage des données"
  value       = module.data_storage.storage_account_name
}
