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
      Module    = "07-provisioners"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "my_ip" {
  description = "EN: Your public IPv4 (no /32) / FR: Votre IPv4 publique (sans /32)"
  type        = string

  validation {
    condition     = can(cidrhost("${var.my_ip}/32", 0))
    error_message = "EN: A plain IPv4 address. / FR : Une adresse IPv4 simple."
  }
}

variable "page_message" {
  description = "EN: Runtime configuration injected at boot / FR: Configuration injectée au démarrage"
  type        = string
  default     = "Booted from a golden image / Démarré depuis une image golden"
}
