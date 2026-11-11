module "app" {
  source = "../modules/app"

  environment = "app"
  tags = {
    Course      = "terraform-cloud-engineer"
    Module      = "11-cicd"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    Environment = "app"
  }
}

output "storage_account" {
  value = module.app.storage_account
}
