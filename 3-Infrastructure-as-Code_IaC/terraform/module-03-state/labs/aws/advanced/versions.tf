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

  # EN: After import, Terraform will ADD these tags — a realistic first change.
  # FR: Après l'import, Terraform AJOUTERA ces étiquettes — un premier changement réaliste.
  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "03-state"
      ManagedBy = "terraform"
    }
  }
}
