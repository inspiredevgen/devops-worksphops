variable "subscription_id" {
  description = "EN: Azure subscription ID (or set ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

variable "budget_name" {
  description = "EN: Budget name / FR: Nom du budget"
  type        = string
  default     = "budget-tf-lab-monthly"
}

variable "monthly_limit" {
  description = "EN: Monthly limit in your billing currency / FR: Limite mensuelle dans votre devise de facturation"
  type        = number
  default     = 10

  validation {
    condition     = var.monthly_limit > 0 && var.monthly_limit <= 500
    error_message = "EN: Must be > 0 and <= 500 for a training subscription. / FR : Doit être > 0 et <= 500 pour un abonnement de formation."
  }
}

variable "alert_emails" {
  description = "EN: Emails that receive budget alerts / FR: Courriels qui reçoivent les alertes"
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0 && alltrue([for e in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "EN: Provide at least one valid email. / FR : Fournissez au moins un courriel valide."
  }
}

variable "actual_thresholds_pct" {
  description = "EN: ACTUAL-spend alert thresholds (%) / FR: Seuils d'alerte sur dépenses RÉELLES (%)"
  type        = object({ warning = number, critical = number })
  default     = { warning = 50, critical = 80 }

  validation {
    condition     = var.actual_thresholds_pct.warning < var.actual_thresholds_pct.critical
    error_message = "EN: warning must be lower than critical. / FR : warning doit être inférieur à critical."
  }
}
