# -----------------------------------------------------------------------------
# Lab 6.A-AZ — STAGING (receives versions validated in dev)
# Lab 6.A-AZ — STAGING (reçoit les versions validées en dev)
#
# EN: The module VERSION is the `?ref=` below. Promote it with:
#       ../../scripts/promote.sh staging prod
# FR: La VERSION du module est le `?ref=` ci-dessous. Promouvez-la avec :
#       ../../scripts/promote.sh staging prod
# -----------------------------------------------------------------------------

module "app" {
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-azurerm-app-stack.git?ref=v1.0.0"

  app_name           = "tflabm06a"
  environment        = "staging"
  replication        = "LRS"
  soft_delete_days   = 14
  log_retention_days = 60
}

output "app" {
  description = "EN: Deployed app-stack / FR: app-stack déployée"
  value = {
    resource_group = module.app.resource_group_name
    storage        = module.app.storage_account_name
  }
}
