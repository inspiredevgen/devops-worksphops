# -----------------------------------------------------------------------------
# Lab 6.A-AWS — STAGING (receives versions validated in dev)
# Lab 6.A-AWS — STAGING (reçoit les versions validées en dev)
#
# EN: The module VERSION is the `?ref=` below. Promote it with:
#       ../../scripts/promote.sh staging prod
# FR: La VERSION du module est le `?ref=` ci-dessous. Promouvez-la avec :
#       ../../scripts/promote.sh staging prod
# -----------------------------------------------------------------------------

module "app" {
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-aws-app-stack.git?ref=v1.0.0"

  app_name           = "tf-lab-m06-adv"
  environment        = "staging"
  versioning         = true
  log_retention_days = 30

  settings = {
    log_level = "info"
  }
}

output "app" {
  description = "EN: Deployed app-stack / FR: app-stack déployée"
  value = {
    bucket = module.app.bucket_name
    config = module.app.config_parameter
  }
}
