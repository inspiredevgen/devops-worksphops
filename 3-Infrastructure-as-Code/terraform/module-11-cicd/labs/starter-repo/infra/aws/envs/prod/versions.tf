terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: Partial backend: CI passes bucket, key and region with -backend-config.
  # FR : Backend partiel : la CI passe bucket, key et region avec -backend-config.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Course      = "terraform-cloud-engineer"
      Module      = "11-cicd"
      ManagedBy   = "terraform"
      Owner       = "platform-team"
      Environment = "prod"
    }
  }
}
