terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: Partial backend: -backend-config=$BACKEND (Module 3) -backend-config="key=capstone/azure/dev.tfstate"
  # FR : Backend partiel : -backend-config=$BACKEND (module 3) -backend-config="key=capstone/azure/dev.tfstate"
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# EN: "none": CI identities are scoped to one resource group and can't register providers.
#     Register Microsoft.Network, Microsoft.Compute and Microsoft.Insights once, by hand (see the guide).
# FR : « none » : les identités de CI sont limitées à un groupe de ressources et ne peuvent pas enregistrer de fournisseurs.
#     Enregistrez Microsoft.Network, Microsoft.Compute et Microsoft.Insights une fois, à la main (voir le guide).
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
