module "app" {
  source = "../../modules/app"

  environment = "prod"
  tags = {
    Course      = "terraform-cloud-engineer"
    Module      = "11-cicd"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    Environment = "prod"
  }
}

output "storage_account" {
  value = module.app.storage_account
}
