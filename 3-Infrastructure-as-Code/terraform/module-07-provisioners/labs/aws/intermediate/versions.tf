terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # EN: Manages local files as real resources (with state, diffs, cleanup).
    # FR: Gère les fichiers locaux comme de vraies ressources (état, diffs, nettoyage).
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "07-provisioners"
      ManagedBy = "terraform"
    }
  }
}
