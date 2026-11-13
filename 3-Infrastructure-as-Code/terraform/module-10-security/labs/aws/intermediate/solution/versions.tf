terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# ✅ EN: No keys in code: credentials come from AWS_PROFILE, SSO or OIDC (lab 10.A).
# ✅ FR : Aucune clé dans le code : les identifiants viennent d'AWS_PROFILE, de SSO ou d'OIDC (lab 10.A).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}
