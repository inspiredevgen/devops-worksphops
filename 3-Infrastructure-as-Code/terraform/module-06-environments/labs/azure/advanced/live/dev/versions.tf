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

# EN: GUARDRAIL — this environment is PINNED to one subscription. Whatever
#     ARM_SUBSCRIPTION_ID says, the provider only targets this one. In a real
#     organisation dev, staging and prod live in separate subscriptions.
# FR: GARDE-FOU — cet environnement est ÉPINGLÉ à un abonnement. Quoi que dise
#     ARM_SUBSCRIPTION_ID, le provider ne cible que celui-ci. Dans une vraie
#     organisation, dev, staging et prod sont dans des abonnements séparés.
provider "azurerm" {
  features {}
  subscription_id = var.expected_subscription_id
}

variable "expected_subscription_id" {
  description = "EN: The ONLY subscription this environment may touch / FR: Le SEUL abonnement que cet environnement peut modifier"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.expected_subscription_id))
    error_message = "EN: A subscription GUID. / FR : Un GUID d'abonnement."
  }
}
