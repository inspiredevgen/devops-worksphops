# -----------------------------------------------------------------------------
# EN: BOOTSTRAP — this configuration uses LOCAL state to create the storage
#     account that will hold every other configuration's state.
# FR: AMORÇAGE — cette configuration utilise un état LOCAL pour créer le compte
#     de stockage qui contiendra l'état de toutes les autres configurations.
# -----------------------------------------------------------------------------
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

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
