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

  # EN: default_tags come from a LOCAL value (see locals.tf).
  # FR: les default_tags proviennent d'une valeur LOCALE (voir locals.tf).
  default_tags {
    tags = local.common_tags
  }
}
