# =============================================================================
# Lab 9.B-AZ — Guardrails in code, then static analysis
# Lab 9.B-AZ — Des garde-fous dans le code, puis l'analyse statique
# =============================================================================

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-tf-lab-m09-storage"
  location = var.location
  tags = merge({
    Course    = "terraform-cloud-engineer"
    Module    = "09-testing"
    ManagedBy = "terraform"
  }, var.rg_tags)
}

module "storage" {
  source = "./modules/secure-storage"

  name                = "sttflabm09${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  environment         = var.environment
  replication_type    = var.replication_type
}

output "storage_account" {
  value = module.storage.name
}
