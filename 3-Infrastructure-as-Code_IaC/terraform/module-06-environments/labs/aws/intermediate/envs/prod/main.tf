# -----------------------------------------------------------------------------
# Lab 6.I-AWS — PROD environment
# Lab 6.I-AWS — Environnement PROD
#
# EN: The ONLY things that differ between envs/dev, envs/staging and
#     envs/prod are the values below and the backend key. Compare them with:
#       diff -r envs/dev envs/prod
# FR: Les SEULES différences entre envs/dev, envs/staging et envs/prod sont
#     les valeurs ci-dessous et la clé de backend. Comparez-les avec :
#       diff -r envs/dev envs/prod
# -----------------------------------------------------------------------------

module "app" {
  source = "../../modules/app-stack"

  app_name           = "tf-lab-m06"
  environment        = "prod"
  versioning         = true
  log_retention_days = 90

  settings = {
    log_level     = "warn"
    feature_flags = "none"
  }
}

output "app" {
  description = "EN: Deployed app-stack / FR: app-stack déployée"
  value = {
    bucket    = module.app.bucket_name
    log_group = module.app.log_group_name
    config    = module.app.config_parameter
  }
}
