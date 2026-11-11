# =============================================================================
# Capstone · Azure · dev
# =============================================================================

module "web" {
  source = "../../../modules/azure-web"

  name        = "capstone-dev"
  environment = "dev"
  location    = "canadacentral"

  # EN: Local runs: the module creates this group. CI (Lab 12.I): switch to the pipeline's group:
  #       resource_group_name = "rg-tf-cicd-dev"  and  create_resource_group = false
  # FR : En local : le module crée ce groupe. En CI (lab 12.I) : passez au groupe du pipeline :
  #       resource_group_name = "rg-tf-cicd-dev"  et  create_resource_group = false
  resource_group_name   = "rg-tf-capstone-dev"
  create_resource_group = true

  vnet_cidr     = "10.120.0.0/16" # EN: see live/address-plan / FR : voir live/address-plan
  min_instances = 1
  max_instances = 2
  app_version   = "1.0.0"

  # EN: Azure requires a key, but no SSH port is ever opened and the private key was destroyed
  #     when this one was generated. Break-glass access: az vmss run-command (Module 7).
  # FR : Azure exige une clé, mais aucun port SSH n'est ouvert et la clé privée a été détruite
  #     à la génération. Accès d'urgence : az vmss run-command (module 7).
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXvYSFZ61GTMk6x3Aq/HMYJiJkirr4EZHo9MyRmQ8tz capstone-no-login(private-key-destroyed)"

  tags = {
    Project     = "terraform-capstone"
    Course      = "terraform-cloud-engineer"
    Module      = "12-capstone"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    Environment = "dev"
  }
}

output "url" {
  value = module.web.url
}

output "fqdn" {
  value = module.web.fqdn
}

output "public_ip" {
  value = module.web.public_ip
}

output "vmss_name" {
  value = module.web.vmss_name
}

output "resource_group_name" {
  value = module.web.resource_group_name
}
