# =============================================================================
# EN: Run this ONCE, as an ADMIN (not TerraformLabRole): it creates identities and trust,
#     which by design the lab role is not allowed to do. Then CI never needs a key again.
# FR : À exécuter UNE fois, en ADMIN (pas TerraformLabRole) : il crée des identités et une
#     relation de confiance, ce que le rôle de lab n'a volontairement pas le droit de faire.
#     Ensuite, la CI n'a plus jamais besoin de clé.
# =============================================================================
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

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "11-cicd"
      ManagedBy = "terraform"
      Owner     = var.owner
    }
  }
}
