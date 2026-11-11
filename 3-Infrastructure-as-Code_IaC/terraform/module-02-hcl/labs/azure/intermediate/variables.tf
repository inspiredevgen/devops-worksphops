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

variable "project" {
  description = "EN: Project name (lowercase) / FR: Nom du projet (minuscules)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,15}$", var.project))
    error_message = "EN: 3-16 chars: lowercase, digits, hyphens. / FR : 3 à 16 caractères : minuscules, chiffres, tirets."
  }
}

variable "environment" {
  description = "EN: Target environment / FR: Environnement cible"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "EN: Must be dev, staging or prod. / FR : Doit être dev, staging ou prod."
  }
}

variable "owner" {
  description = "EN: Team or person accountable / FR: Équipe ou personne responsable"
  type        = string
}

variable "extra_tags" {
  description = "EN: Additional tags / FR: Étiquettes supplémentaires"
  type        = map(string)
  default     = {}
}

# EN: Optional override. null = use the per-environment default from locals.
# FR: Surcharge optionnelle. null = utiliser la valeur par défaut de l'environnement (locals).
variable "log_retention_days_override" {
  description = "EN: Override Log Analytics retention (30-730) / FR: Surcharger la rétention Log Analytics (30-730)"
  type        = number
  default     = null

  validation {
    condition     = var.log_retention_days_override == null || (coalesce(var.log_retention_days_override, 30) >= 30 && coalesce(var.log_retention_days_override, 30) <= 730)
    error_message = "EN: Must be null or between 30 and 730. / FR : Doit être null ou entre 30 et 730."
  }
}
