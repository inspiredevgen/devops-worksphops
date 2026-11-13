terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# EN: Run with AWS_PROFILE=tf-lab (Module 0).
# FR: Exécutez avec AWS_PROFILE=tf-lab (module 0).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "02-hcl"
      ManagedBy = "terraform"
    }
  }
}
