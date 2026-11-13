terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: terraform init -backend-config=$BACKEND -backend-config=backend.hcl
  # FR: terraform init -backend-config=$BACKEND -backend-config=backend.hcl
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"

  # EN: GUARDRAIL — the provider REFUSES to run against any other account.
  #     In a real organisation dev, staging and prod are separate accounts:
  #     running prod code with dev credentials (or vice-versa) fails instantly.
  # FR: GARDE-FOU — le provider REFUSE de s'exécuter sur tout autre compte.
  #     Dans une vraie organisation, dev, staging et prod sont des comptes
  #     séparés : exécuter le code prod avec des identifiants dev (ou l'inverse)
  #     échoue immédiatement.
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "06-environments"
      ManagedBy = "terraform"
    }
  }
}

variable "expected_account_id" {
  description = "EN: The ONLY AWS account this environment may touch / FR: Le SEUL compte AWS que cet environnement peut modifier"
  type        = string

  validation {
    condition     = can(regex("^\\d{12}$", var.expected_account_id))
    error_message = "EN: A 12-digit AWS account ID. / FR : Un ID de compte AWS à 12 chiffres."
  }
}
