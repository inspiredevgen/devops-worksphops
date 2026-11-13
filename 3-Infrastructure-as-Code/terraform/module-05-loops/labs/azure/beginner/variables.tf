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

variable "group_count" {
  description = "EN: How many numbered resource groups (0-5) / FR: Nombre de groupes numérotés (0-5)"
  type        = number
  default     = 2

  validation {
    condition     = var.group_count >= 0 && var.group_count <= 5
    error_message = "EN: Between 0 and 5. / FR : Entre 0 et 5."
  }
}

variable "group_names" {
  description = "EN: Named resource groups — ORDER MATTERS with count! / FR: Groupes nommés — l'ORDRE COMPTE avec count !"
  type        = list(string)
  default     = ["logs", "assets", "backups"]

  validation {
    condition     = alltrue([for n in var.group_names : can(regex("^[a-z][a-z0-9-]{1,30}$", n))])
    error_message = "EN: Lowercase names, 2-31 chars. / FR : Noms en minuscules, 2 à 31 caractères."
  }
}

variable "create_audit_group" {
  description = "EN: Create the optional audit resource group? / FR: Créer le groupe d'audit optionnel ?"
  type        = bool
  default     = false
}
