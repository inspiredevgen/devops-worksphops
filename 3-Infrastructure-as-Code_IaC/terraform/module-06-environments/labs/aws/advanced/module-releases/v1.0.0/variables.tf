variable "app_name" {
  description = "EN: Application name / FR: Nom de l'application"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.app_name))
    error_message = "EN: 3-21 chars, lowercase, digits, hyphens. / FR : 3 à 21 caractères, minuscules, chiffres, tirets."
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

variable "versioning" {
  description = "EN: Enable bucket versioning / FR: Activer le versionnage du compartiment"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "EN: CloudWatch log retention / FR: Rétention des journaux CloudWatch"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "EN: Use a CloudWatch-supported value (1, 3, 5, 7, 14, 30, 60, 90, …). / FR : Utilisez une valeur prise en charge par CloudWatch (1, 3, 5, 7, 14, 30, 60, 90, …)."
  }
}

variable "settings" {
  description = "EN: Application settings stored in SSM / FR: Paramètres applicatifs stockés dans SSM"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "EN: Extra tags / FR: Étiquettes supplémentaires"
  type        = map(string)
  default     = {}
}
