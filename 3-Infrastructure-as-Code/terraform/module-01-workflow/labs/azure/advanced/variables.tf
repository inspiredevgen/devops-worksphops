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

# EN: Bumping this rotates the managed identity (new random name → replacement).
# FR: Changer ceci fait tourner l'identité managée (nouveau nom aléatoire → remplacement).
variable "identity_generation" {
  description = "EN: Identity generation number / FR: Numéro de génération de l'identité"
  type        = number
  default     = 1
}

# EN: Bumping the release recreates the "release-current" container.
# FR: Changer la version recrée le conteneur « release-current ».
variable "release_version" {
  description = "EN: Application release / FR: Version de l'application"
  type        = string
  default     = "1.0.0"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.release_version))
    error_message = "EN: Use semantic versioning, e.g. 1.2.3. / FR : Utilisez le versionnage sémantique, ex. 1.2.3."
  }
}
