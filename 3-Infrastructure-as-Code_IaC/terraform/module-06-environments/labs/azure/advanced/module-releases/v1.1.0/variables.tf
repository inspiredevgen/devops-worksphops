variable "app_name" {
  description = "EN: Application name (lowercase letters/digits) / FR: Nom de l'application (minuscules/chiffres)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.app_name))
    error_message = "EN: 3-10 lowercase letters or digits. / FR : 3 à 10 minuscules ou chiffres."
  }
}

variable "environment" {
  description = "EN: Environment name / FR: Nom de l'environnement"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "EN: dev, staging or prod. / FR : dev, staging ou prod."
  }
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

variable "replication" {
  description = "EN: Storage replication / FR: Réplication du stockage"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS"], var.replication)
    error_message = "EN: LRS, ZRS or GRS. / FR : LRS, ZRS ou GRS."
  }
}

variable "soft_delete_days" {
  description = "EN: Blob soft-delete retention (1-365) / FR: Rétention de la suppression réversible des blobs (1-365)"
  type        = number
  default     = 7
}

variable "log_retention_days" {
  description = "EN: Log Analytics retention (30-730) / FR: Rétention Log Analytics (30-730)"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "EN: Between 30 and 730. / FR : Entre 30 et 730."
  }
}

variable "tags" {
  description = "EN: Extra tags / FR: Étiquettes supplémentaires"
  type        = map(string)
  default     = {}
}

# EN: v1.1.0 — new OPTIONAL input (safe default) → MINOR release.
# FR: v1.1.0 — nouvelle entrée OPTIONNELLE (valeur par défaut sûre) → version MINEURE.
variable "data_classification" {
  description = "EN: Data classification tag / FR: Étiquette de classification des données"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential"], var.data_classification)
    error_message = "EN: public, internal or confidential. / FR : public, internal ou confidential."
  }
}
