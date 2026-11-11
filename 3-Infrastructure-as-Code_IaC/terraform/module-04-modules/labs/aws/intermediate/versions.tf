# EN: ROOT module: configures the provider and pins versions.
# FR: Module RACINE : configure le provider et épingle les versions.
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
      Module    = "04-modules"
      ManagedBy = "terraform"
    }
  }
}
