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

  # EN: Owner comes from default_tags: invisible to code scanners, visible in the plan's tags_all.
  # FR : Owner vient de default_tags : invisible pour les scanners de code, visible dans tags_all du plan.
  default_tags {
    tags = merge(
      {
        Course    = "terraform-cloud-engineer"
        Module    = "10-security"
        ManagedBy = "terraform"
      },
      var.owner == "" ? {} : { Owner = var.owner }
    )
  }
}
