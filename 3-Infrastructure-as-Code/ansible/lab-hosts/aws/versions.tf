# =============================================================================
# Lab hosts (AWS) for the whole Ansible course: one stack, one preset per lab.
# Hôtes de lab (AWS) pour tout le cours Ansible : une pile, un préréglage par lab.
#   terraform apply -var-file=presets/<lab>.tfvars -var="inventory_path=$PWD/../../<module>/labs/aws/<tier>/inventory.yml"
# =============================================================================
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "ansible-cloud-engineer"
      Module    = var.module_tag
      ManagedBy = "terraform"
    }
  }
}
