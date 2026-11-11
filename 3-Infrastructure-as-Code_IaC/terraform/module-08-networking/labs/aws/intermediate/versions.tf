terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

locals {
  default_tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "08-networking"
    ManagedBy = "terraform"
  }
}

# EN: The default (un-aliased) provider: primary region.
# FR : Le provider par défaut (sans alias) : région principale.
provider "aws" {
  region = var.primary_region
  default_tags { tags = local.default_tags }
}

# EN: A SECOND configuration of the same provider, for another region. Referenced as aws.secondary.
# FR : Une SECONDE configuration du même provider, pour une autre région. Référencée par aws.secondary.
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  default_tags { tags = local.default_tags }
}
