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

variable "environment" {
  description = "EN: Passed to the module / FR: Transmis au module"
  type        = string
  default     = "dev"
}

variable "replication_type" {
  description = "EN: Passed to the module / FR: Transmis au module"
  type        = string
  default     = "LRS"
}

variable "rg_tags" {
  description = "EN: Resource group tags (add Owner to silence the check) / FR: Étiquettes du RG (ajoutez Owner pour faire taire la vérification)"
  type        = map(string)
  default     = {}
}
