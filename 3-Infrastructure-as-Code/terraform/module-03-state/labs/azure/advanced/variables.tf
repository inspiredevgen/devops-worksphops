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

variable "legacy_storage_account_name" {
  description = "EN: Storage account created by scripts/setup.sh / FR: Compte de stockage créé par scripts/setup.sh"
  type        = string
}

# EN: Azure import IDs are full Azure Resource Manager IDs.
# FR: Les ID d'import Azure sont des ID complets d'Azure Resource Manager.
variable "legacy_rg_id" {
  description = "EN: Resource group ID / FR: ID du groupe de ressources"
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.legacy_rg_id))
    error_message = "EN: Expected /subscriptions/<id>/resourceGroups/<name>. / FR : Attendu /subscriptions/<id>/resourceGroups/<nom>."
  }
}

variable "legacy_storage_id" {
  description = "EN: Storage account ID / FR: ID du compte de stockage"
  type        = string
}

variable "legacy_nsg_id" {
  description = "EN: Network security group ID / FR: ID du groupe de sécurité réseau"
  type        = string
}
