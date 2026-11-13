# -----------------------------------------------------------------------------
# Lab 6.I-AZ — STAGING environment
# Lab 6.I-AZ — Environnement STAGING
#
# EN: Only the values below and the backend key differ between environments.
#     Compare them with: diff -r envs/dev envs/prod
# FR: Seules les valeurs ci-dessous et la clé de backend diffèrent entre
#     environnements. Comparez-les avec : diff -r envs/dev envs/prod
# -----------------------------------------------------------------------------

module "app" {
  source = "../../modules/app-stack"

  app_name           = "tflabm06"
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
