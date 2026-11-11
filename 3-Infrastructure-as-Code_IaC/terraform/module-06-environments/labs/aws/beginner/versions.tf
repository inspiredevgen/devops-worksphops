terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: Remote state from Module 3. Each WORKSPACE gets its own state object:
  #       default   → s3://<bucket>/module-06/workspaces.tfstate
  #       dev       → s3://<bucket>/env:/dev/module-06/workspaces.tfstate
  #       prod      → s3://<bucket>/env:/prod/module-06/workspaces.tfstate
  # FR: État distant du module 3. Chaque WORKSPACE a son propre objet d'état :
  #       default   → s3://<bucket>/module-06/workspaces.tfstate
  #       dev       → s3://<bucket>/env:/dev/module-06/workspaces.tfstate
  #       prod      → s3://<bucket>/env:/prod/module-06/workspaces.tfstate
  backend "s3" {}

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
      Course      = "terraform-cloud-engineer"
      Module      = "06-environments"
      ManagedBy   = "terraform"
      Environment = terraform.workspace
    }
  }
}
