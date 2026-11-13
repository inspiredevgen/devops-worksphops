# -----------------------------------------------------------------------------
# Lab 6.I-AZ — PROD environment
# Lab 6.I-AZ — Environnement PROD
#
# EN: Only the values below and the backend key differ between environments.
#     Compare them with: diff -r envs/dev envs/prod
# FR: Seules les valeurs ci-dessous et la clé de backend diffèrent entre
#     environnements. Comparez-les avec : diff -r envs/dev envs/prod
# -----------------------------------------------------------------------------

module "app" {
  source = "../../modules/app-stack"

  app_name           = "tflabm06"
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
