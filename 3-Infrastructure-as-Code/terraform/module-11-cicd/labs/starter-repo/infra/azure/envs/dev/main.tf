module "app" {
  source = "../../modules/app"

  environment = "dev"
  tags = {
    Course      = "terraform-cloud-engineer"
    Module      = "11-cicd"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    Environment = "dev"
  }
}

output "storage_account" {
  value = module.app.storage_account
}
