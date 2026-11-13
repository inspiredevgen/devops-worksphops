# -----------------------------------------------------------------------------
# Lab 6.A-AZ — PROD (receives versions validated in staging — never directly from dev)
# Lab 6.A-AZ — PROD (reçoit les versions validées en staging — jamais directement depuis dev)
#
# EN: Last stop. Its `?ref=` changes only through: ../../scripts/promote.sh staging prod
# FR: Dernière étape. Son `?ref=` ne change que via : ../../scripts/promote.sh staging prod
# -----------------------------------------------------------------------------

module "app" {
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-azurerm-app-stack.git?ref=v1.0.0"

  app_name           = "tflabm06a"
  environment        = "prod"
  replication        = "GRS"
  soft_delete_days   = 30
  log_retention_days = 90
}

output "app" {
  description = "EN: Deployed app-stack / FR: app-stack déployée"
  value = {
    resource_group = module.app.resource_group_name
    storage        = module.app.storage_account_name
  }
}
