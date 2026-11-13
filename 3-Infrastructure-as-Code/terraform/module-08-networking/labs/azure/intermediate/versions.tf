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

# EN: On Azure you do NOT need an alias to use another REGION (location is a resource argument).
#     You need one for another SUBSCRIPTION or TENANT, which is how real hub/spoke estates are split.
#     Here it points at the same subscription by default, so the lab works with one subscription.
# FR : Sur Azure, pas besoin d'alias pour une autre RÉGION (location est un argument de ressource).
#     Il en faut un pour un autre ABONNEMENT ou LOCATAIRE, ce qui découpe les vrais environnements hub/spoke.
#     Ici, il pointe par défaut sur le même abonnement : le lab fonctionne avec un seul abonnement.
provider "azurerm" {
  alias = "secondary"
  features {}
  # EN: null → falls back to var.subscription_id, then to ARM_SUBSCRIPTION_ID.
  # FR : null → repli sur var.subscription_id, puis sur ARM_SUBSCRIPTION_ID.
  subscription_id = var.secondary_subscription_id != null ? var.secondary_subscription_id : var.subscription_id
}
