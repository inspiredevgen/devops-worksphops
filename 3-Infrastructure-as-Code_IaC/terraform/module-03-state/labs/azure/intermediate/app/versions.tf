terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: PARTIAL configuration — values come from ../backend.hcl and -backend-config:
  #       terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
  #     Auth: the backend uses the same ARM_* service principal and reads the
  #     storage account key through Azure Resource Manager (Contributor is enough).
  # FR: Configuration PARTIELLE — les valeurs viennent de ../backend.hcl et de -backend-config :
  #       terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
  #     Authentification : le backend utilise le même principal de service ARM_* et lit
  #     la clé du compte de stockage via Azure Resource Manager (Contributeur suffit).
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
