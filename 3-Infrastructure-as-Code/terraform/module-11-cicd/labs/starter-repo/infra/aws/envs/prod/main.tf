module "app" {
  source = "../../modules/app"

  environment = "prod"
  message     = "prod: version 1"
}

output "bucket" {
  value = module.app.bucket
}

output "parameter" {
  value = module.app.parameter
}
