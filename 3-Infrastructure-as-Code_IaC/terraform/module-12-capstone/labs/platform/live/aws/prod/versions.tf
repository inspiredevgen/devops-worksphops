terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  # EN: Partial backend. Locally: -backend-config=$BACKEND (Module 3) -backend-config="key=capstone/aws/prod.tfstate"
  #     In CI: scripts/ci/init.sh (Module 11) passes the same values.
  # FR : Backend partiel. En local : -backend-config=$BACKEND (module 3) -backend-config="key=capstone/aws/prod.tfstate"
  #     En CI : scripts/ci/init.sh (module 11) passe les mêmes valeurs.
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
      Project     = "terraform-capstone"
      Course      = "terraform-cloud-engineer"
      Module      = "12-capstone"
      ManagedBy   = "terraform"
      Owner       = "platform-team"
      Environment = "prod"
    }
  }
}
