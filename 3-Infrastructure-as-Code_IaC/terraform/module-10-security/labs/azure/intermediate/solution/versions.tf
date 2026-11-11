terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# ✅ EN: No credentials in code: az login, ARM_* variables, or OIDC (lab 10.A).
# ✅ FR : Aucun identifiant dans le code : az login, variables ARM_*, ou OIDC (lab 10.A).
provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true # EN: data-plane calls use Entra ID, since shared keys are disabled / FR : appels au plan de données via Entra ID, les clés partagées étant désactivées
}
