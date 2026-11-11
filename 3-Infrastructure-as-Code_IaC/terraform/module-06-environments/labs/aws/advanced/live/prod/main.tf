# -----------------------------------------------------------------------------
# Lab 6.A-AWS — PROD (receives versions validated in staging — never directly from dev)
# Lab 6.A-AWS — PROD (reçoit les versions validées en staging — jamais directement depuis dev)
#
# EN: Last stop. Its `?ref=` changes only through: ../../scripts/promote.sh staging prod
# FR: Dernière étape. Son `?ref=` ne change que via : ../../scripts/promote.sh staging prod
# -----------------------------------------------------------------------------

module "app" {
  source = "git::https://github.com/<YOUR-GITHUB-USER>/terraform-aws-app-stack.git?ref=v1.0.0"

  app_name           = "tf-lab-m06-adv"
  environment        = "prod"
  versioning         = true
  log_retention_days = 90

  settings = {
    log_level = "warn"
  }
}

output "app" {
  description = "EN: Deployed app-stack / FR: app-stack déployée"
  value = {
    bucket = module.app.bucket_name
    config = module.app.config_parameter
  }
}
