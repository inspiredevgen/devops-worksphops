terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: Remote state from Module 3. Each WORKSPACE gets its own blob:
  #       default → module-06/workspaces.tfstate
  #       dev     → module-06/workspaces.tfstateenv:dev
  #       prod    → module-06/workspaces.tfstateenv:prod
  # FR: État distant du module 3. Chaque WORKSPACE a son propre blob :
  #       default → module-06/workspaces.tfstate
  #       dev     → module-06/workspaces.tfstateenv:dev
  #       prod    → module-06/workspaces.tfstateenv:prod
  backend "azurerm" {}

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
