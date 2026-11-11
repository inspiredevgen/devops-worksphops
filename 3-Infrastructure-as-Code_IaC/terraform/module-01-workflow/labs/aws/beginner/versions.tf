terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # EN: "random" generates values (like a unique suffix) and keeps them in state.
    # FR: « random » génère des valeurs (comme un suffixe unique) et les garde dans l'état.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# EN: Run with AWS_PROFILE=tf-lab (the role created in Module 0).
# FR: Exécutez avec AWS_PROFILE=tf-lab (le rôle créé au module 0).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "01-workflow"
      ManagedBy = "terraform"
    }
  }
}
