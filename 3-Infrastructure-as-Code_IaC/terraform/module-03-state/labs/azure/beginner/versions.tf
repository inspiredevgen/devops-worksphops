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

# EN: No backend block → LOCAL state in ./terraform.tfstate (this lab's topic).
# FR: Aucun bloc backend → état LOCAL dans ./terraform.tfstate (le sujet de ce lab).
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
