terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # EN: Builds MIME multi-part cloud-init documents.
    # FR: Construit des documents cloud-init MIME multi-parties.
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
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
