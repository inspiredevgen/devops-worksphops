variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "budget_name" {
  description = "EN: Budget name / FR: Nom du budget"
  type        = string
  default     = "tf-lab-monthly-budget"
}

variable "monthly_limit_usd" {
  description = "EN: Monthly spending limit in USD / FR: Limite de dépenses mensuelle en USD"
  type        = number
  default     = 10

  validation {
    condition     = var.monthly_limit_usd > 0 && var.monthly_limit_usd <= 500
    error_message = "EN: Must be > 0 and <= 500 for a training account. / FR : Doit être > 0 et <= 500 pour un compte de formation."
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
