terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: Partial backend: CI passes the storage details and key with -backend-config.
  # FR : Backend partiel : la CI passe les détails du stockage et la clé avec -backend-config.
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# EN: In CI, ARM_USE_OIDC/ARM_CLIENT_ID/ARM_TENANT_ID/ARM_SUBSCRIPTION_ID come from the workflow.
#     "none": an RG-scoped identity can't register resource providers on the subscription.
# FR : En CI, ARM_USE_OIDC/ARM_CLIENT_ID/ARM_TENANT_ID/ARM_SUBSCRIPTION_ID viennent du workflow.
#     « none » : une identité limitée à un RG ne peut pas enregistrer de fournisseurs sur l'abonnement.
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}
