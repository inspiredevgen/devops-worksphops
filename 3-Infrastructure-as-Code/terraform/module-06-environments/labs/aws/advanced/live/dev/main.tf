# -----------------------------------------------------------------------------
# Lab 6.A-AWS — DEV (first to receive new module versions)
# Lab 6.A-AWS — DEV (premier à recevoir les nouvelles versions du module)
#
# EN: The module VERSION is the `?ref=` below. Promote it with:
#       ../../scripts/promote.sh dev staging
# FR: La VERSION du module est le `?ref=` ci-dessous. Promouvez-la avec :
#       ../../scripts/promote.sh dev staging
# -----------------------------------------------------------------------------

module "app" {
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-aws-app-stack.git?ref=v1.0.0"

  app_name           = "tf-lab-m06-adv"
  environment        = "dev"
  versioning         = false
  log_retention_days = 7

  settings = {
    log_level = "debug"
  }
}

output "app" {
  description = "EN: Deployed app-stack / FR: app-stack déployée"
  value = {
    bucket = module.app.bucket_name
    config = module.app.config_parameter
  }
}
