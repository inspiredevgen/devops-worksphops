terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# EN: Run with the ARM_* service principal variables from Module 0.
# FR: Exécutez avec les variables ARM_* du principal de service du module 0.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
