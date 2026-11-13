# -----------------------------------------------------------------------------
# EN: Terraform and provider version constraints.
# FR: Contraintes de version de Terraform et des providers.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0" # EN: any 4.x release / FR: toute version 4.x
    }
  }
}

# EN: AzureRM 4.x REQUIRES an explicit subscription. We pass it as a variable;
#     you can instead export ARM_SUBSCRIPTION_ID and leave the variable null.
#     Credentials come from `az login` (Azure CLI) — never hard-code secrets.
# FR: AzureRM 4.x EXIGE un abonnement explicite. Nous le passons en variable ;
#     vous pouvez aussi exporter ARM_SUBSCRIPTION_ID et laisser la variable nulle.
#     Les identifiants proviennent de `az login` — ne codez jamais de secrets.
provider "azurerm" {
  features {} # EN: required block, even if empty / FR: bloc obligatoire, même vide

  subscription_id = var.subscription_id
}
