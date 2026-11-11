module "app" {
  source = "../modules/app"

  environment = "app"
  message     = "Hello from the pipeline! / Bonjour depuis le pipeline !"
}

output "bucket" {
  value = module.app.bucket
}

output "parameter" {
  value = module.app.parameter
}
