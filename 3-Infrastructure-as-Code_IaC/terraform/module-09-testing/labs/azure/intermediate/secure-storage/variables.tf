# ---------------------------------------------- Layer 1: input validation

variable "name" {
  description = "EN: Storage account name: 3-24 lowercase letters/digits, starts with \"st\" / FR: Nom du compte : 3 à 24 minuscules/chiffres, commence par « st »"
  type        = string

  validation {
    condition     = can(regex("^st[a-z0-9]{1,22}$", var.name))
    error_message = "EN: 3-24 lowercase letters or digits, starting with \"st\". / FR : 3 à 24 minuscules ou chiffres, commençant par « st »."
  }
}

variable "resource_group_name" {
  description = "EN: Existing resource group / FR: Groupe de ressources existant"
  type        = string
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
}

variable "environment" {
  description = "EN: dev, stage or prod / FR: dev, stage ou prod"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "EN: environment must be dev, stage or prod. / FR : environment doit valoir dev, stage ou prod."
  }
}

variable "replication_type" {
  description = "EN: LRS, ZRS, GRS, GZRS, RAGRS or RAGZRS / FR: LRS, ZRS, GRS, GZRS, RAGRS ou RAGZRS"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "EN: Unknown replication type. / FR : Type de réplication inconnu."
  }
}

variable "delete_retention_days" {
  description = "EN: Soft-delete retention for blobs (1-365) / FR: Rétention de la suppression réversible des blobs (1-365)"
  type        = number
  default     = 7

  validation {
    condition     = var.delete_retention_days >= 1 && var.delete_retention_days <= 365 && floor(var.delete_retention_days) == var.delete_retention_days
    error_message = "EN: A whole number of days between 1 and 365. / FR : Un nombre entier de jours entre 1 et 365."
  }
}
