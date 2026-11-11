# -----------------------------------------------------------------------------
# EN: Each environment folder is its OWN root module: its own backend key,
#     its own provider configuration, its own state, its own lock.
# FR: Chaque dossier d'environnement est son PROPRE module racine : sa propre
#     clé de backend, sa propre configuration de provider, son propre état,
#     son propre verrou.
# -----------------------------------------------------------------------------
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

  default_tags {
    tags = {
      Course    = "terraform-cloud-engineer"
      Module    = "06-environments"
      ManagedBy = "terraform"
    }
  }
}
