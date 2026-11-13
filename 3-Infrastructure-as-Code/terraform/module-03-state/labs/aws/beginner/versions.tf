terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# EN: No backend block → LOCAL state in ./terraform.tfstate (this lab's topic).
# FR: Aucun bloc backend → état LOCAL dans ./terraform.tfstate (le sujet de ce lab).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "03-state"
      ManagedBy = "terraform"
    }
  }
}
