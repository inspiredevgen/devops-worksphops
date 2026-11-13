terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: PARTIAL configuration — values come from ../backend.hcl and -backend-config:
  #       terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
  #     Backend blocks cannot use variables, which is why partial config exists.
  # FR: Configuration PARTIELLE — les valeurs viennent de ../backend.hcl et de -backend-config :
  #       terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
  #     Les blocs backend n'acceptent pas de variables : d'où la configuration partielle.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

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
