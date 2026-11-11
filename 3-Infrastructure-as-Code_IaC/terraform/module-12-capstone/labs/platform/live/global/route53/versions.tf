terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# EN: Route 53 is a global service; any region works for the provider.
# FR : Route 53 est un service mondial ; n'importe quelle région convient au provider.
provider "aws" {
  region = "ca-central-1"

  default_tags {
    tags = {
      Project   = "terraform-capstone"
      Course    = "terraform-cloud-engineer"
      Module    = "12-capstone"
      ManagedBy = "terraform"
      Owner     = "platform-team"
    }
  }
}
