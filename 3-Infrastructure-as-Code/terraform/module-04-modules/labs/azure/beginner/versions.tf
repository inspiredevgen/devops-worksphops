terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# EN: The AVM module also uses the `azapi` (and `modtm`) providers internally.
#     `terraform init` installs them automatically; azapi reuses the same
#     ARM_* credentials. You don't need to configure them here.
# FR: Le module AVM utilise aussi en interne les providers `azapi` (et `modtm`).
#     `terraform init` les installe automatiquement ; azapi réutilise les mêmes
#     identifiants ARM_*. Inutile de les configurer ici.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
