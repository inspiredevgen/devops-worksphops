# -----------------------------------------------------------------------------
# EN: Terraform and provider version constraints. Always pin versions so the
#     same code behaves the same way on every machine and in CI.
# FR: Contraintes de version de Terraform et des providers. Épinglez toujours
#     les versions pour que le même code se comporte de la même façon partout.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # EN: any 6.x release / FR: toute version 6.x
    }
  }
}

# EN: The provider reads credentials from your AWS CLI profile (AWS_PROFILE)
#     or environment variables. NEVER hard-code access keys here.
# FR: Le provider lit les identifiants depuis votre profil AWS CLI (AWS_PROFILE)
#     ou les variables d'environnement. Ne codez JAMAIS de clés d'accès ici.
provider "aws" {
  region = var.aws_region

  # EN: Tags applied automatically to every taggable resource.
  # FR: Étiquettes appliquées automatiquement à chaque ressource étiquetable.
  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "00-setup"
      ManagedBy = "terraform"
    }
  }
}
