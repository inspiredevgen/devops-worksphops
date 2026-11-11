# -----------------------------------------------------------------------------
# EN: The BOOTSTRAP problem: the state bucket must exist before any
#     configuration can store state in it. So this small configuration uses
#     LOCAL state to create the bucket. (Stretch: migrate it afterwards.)
# FR: Le problème de l'AMORÇAGE : le compartiment d'état doit exister avant
#     qu'une configuration puisse y stocker son état. Cette petite configuration
#     utilise donc un état LOCAL pour créer le compartiment. (Défi : le migrer ensuite.)
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "03-state"
      ManagedBy = "terraform"
      Purpose   = "terraform-state"
    }
  }
}
