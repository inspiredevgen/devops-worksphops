terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # EN: azuread manages Microsoft Entra ID objects (apps, service principals).
    # FR: azuread gère les objets Microsoft Entra ID (applications, principaux de service).
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    # EN: time provides rotation timestamps for the secret.
    # FR: time fournit des horodatages de rotation pour le secret.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

# EN: Run this lab while signed in with `az login` as a subscription Owner.
# FR: Exécutez ce lab connecté avec `az login` en tant que Propriétaire de l'abonnement.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}
