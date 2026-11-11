# -----------------------------------------------------------------------------
# EN: Each environment folder is its OWN root module: own backend key, own
#     provider configuration (could target another SUBSCRIPTION), own state.
#     The subscription comes from ARM_SUBSCRIPTION_ID.
# FR: Chaque dossier d'environnement est son PROPRE module racine : sa propre
#     clé de backend, sa propre configuration de provider (pourrait cibler un
#     autre ABONNEMENT), son propre état. L'abonnement vient de ARM_SUBSCRIPTION_ID.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: terraform init -backend-config=$BACKEND -backend-config=backend.hcl
  # FR: terraform init -backend-config=$BACKEND -backend-config=backend.hcl
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
}
