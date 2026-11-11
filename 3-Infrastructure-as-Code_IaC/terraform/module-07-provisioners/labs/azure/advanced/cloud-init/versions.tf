terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

variable "my_ip" {
  description = "EN: Your public IPv4 (no /32) / FR: Votre IPv4 publique (sans /32)"
  type        = string

  validation {
    condition     = can(cidrhost("${var.my_ip}/32", 0))
    error_message = "EN: A plain IPv4 address. / FR : Une adresse IPv4 simple."
  }
}

variable "ssh_public_key_path" {
  description = "EN: SSH public key / FR: Clé SSH publique"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "environment" {
  description = "EN: Environment label shown on the page / FR: Environnement affiché sur la page"
  type        = string
  default     = "dev"
}
