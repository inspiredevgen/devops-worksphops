# =============================================================================
# Lab hosts (Azure) for the whole Ansible course: one stack, one preset per lab.
# Hôtes de lab (Azure) pour tout le cours Ansible : une pile, un préréglage par lab.
#   terraform apply -var-file=presets/<lab>.tfvars -var="inventory_path=$PWD/../../<module>/labs/azure/<tier>/inventory.yml"
# =============================================================================
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false # EN: lab hosts are disposable / FR : les hôtes de lab sont jetables
    }
  }
  subscription_id = var.subscription_id
}
