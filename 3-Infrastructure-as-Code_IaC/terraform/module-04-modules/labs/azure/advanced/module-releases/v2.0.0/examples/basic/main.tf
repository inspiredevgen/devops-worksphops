# EN: Minimal working example — every published module should have one.
# FR: Exemple minimal fonctionnel — tout module publié devrait en avoir un.

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-network-example"
  location = "canadacentral"
}

module "network" {
  source = "../.."

  name                = "example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  vnet_cidr           = "10.99.0.0/16"
  subnet_names        = ["app"]
}

output "subnet_ids" {
  value = module.network.subnet_ids
}
