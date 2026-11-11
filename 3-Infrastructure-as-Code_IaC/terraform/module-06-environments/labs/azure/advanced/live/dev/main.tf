# -----------------------------------------------------------------------------
# Lab 6.A-AZ — DEV (first to receive new module versions)
# Lab 6.A-AZ — DEV (premier à recevoir les nouvelles versions du module)
#
# EN: The module VERSION is the `?ref=` below. Promote it with:
#       ../../scripts/promote.sh dev staging
# FR: La VERSION du module est le `?ref=` ci-dessous. Promouvez-la avec :
#       ../../scripts/promote.sh dev staging
# -----------------------------------------------------------------------------

module "app" {
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-azurerm-app-stack.git?ref=v1.0.0"

  app_name           = "tflabm06a"
  environment        = "dev"
  replication        = "LRS"
  soft_delete_days   = 7
  log_retention_days = 30
}

output "app" {
  description = "EN: Deployed app-stack / FR: app-stack déployée"
  value = {
    resource_group = module.app.resource_group_name
    storage        = module.app.storage_account_name
  }
}
