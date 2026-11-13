module "app" {
  source = "../../modules/app"

  environment = "dev"
  message     = "dev: version 1"
}

output "bucket" {
  value = module.app.bucket
}

output "parameter" {
  value = module.app.parameter
}
