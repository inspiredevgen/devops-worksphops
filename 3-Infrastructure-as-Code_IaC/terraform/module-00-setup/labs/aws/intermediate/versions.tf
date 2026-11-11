terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# EN: Run this lab with your ADMIN profile (e.g. AWS_PROFILE=tf-admin).
#     It bootstraps the restricted role you will use for the rest of the course.
# FR: Exécutez ce lab avec votre profil ADMIN (ex. AWS_PROFILE=tf-admin).
#     Il crée le rôle restreint que vous utiliserez pour le reste du cours.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "00-setup"
      ManagedBy = "terraform"
    }
  }
}
