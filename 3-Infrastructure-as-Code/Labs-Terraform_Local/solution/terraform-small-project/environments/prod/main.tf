# This file is IDENTICAL in dev/ and prod/. Only terraform.tfvars differs.
# If you ever need to edit one and not the other, ask why first.

locals {
  name_prefix = "${var.project_name}-${var.team}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name_prefix         = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
}

module "bastion" {
  source = "../../modules/bastion"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.public_subnet_ids[0]
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  public_key        = file(pathexpand(var.ssh_public_key_path))
}

module "app_service" {
  source = "../../modules/app_service"

  name_prefix               = local.name_prefix
  environment               = var.environment
  aws_region                = var.aws_region
  vpc_id                    = module.network.vpc_id
  subnet_id                 = module.network.public_subnet_ids[length(module.network.public_subnet_ids) - 1]
  instance_type             = var.instance_type
  allowed_http_cidrs        = var.allowed_http_cidrs
  key_name                  = module.bastion.key_name
  bastion_security_group_id = module.bastion.security_group_id
  app_repo_url              = var.app_repo_url
  app_version               = var.app_version
  enable_eip                = var.enable_eip
}
