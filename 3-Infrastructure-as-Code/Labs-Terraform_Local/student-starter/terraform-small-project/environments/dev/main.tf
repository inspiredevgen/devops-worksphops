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

# TODO (Phase 2): add module "bastion" — inputs: see modules/bastion/variables.tf
#   subnet = FIRST public subnet, public_key = file(pathexpand(var.ssh_public_key_path))

# TODO (Phase 3): add module "app_service" — inputs: see modules/app_service/variables.tf
#   subnet = LAST public subnet, key_name and bastion_security_group_id come from module.bastion
