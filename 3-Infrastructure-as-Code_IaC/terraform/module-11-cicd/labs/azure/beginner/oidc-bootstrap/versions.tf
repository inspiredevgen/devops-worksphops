# =============================================================================
# EN: Run this ONCE as a user who may create ROLE ASSIGNMENTS (Owner or User Access
#     Administrator), signed in with `az login`. The Module 0 service principal is only
#     Contributor, so it can't grant roles, by design.
# FR : À exécuter UNE fois avec un utilisateur autorisé à créer des ATTRIBUTIONS DE RÔLE
#     (Owner ou User Access Administrator), connecté avec `az login`. Le principal de service
#     du module 0 n'est que Contributor : il ne peut pas attribuer de rôles, par conception.
# =============================================================================
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
