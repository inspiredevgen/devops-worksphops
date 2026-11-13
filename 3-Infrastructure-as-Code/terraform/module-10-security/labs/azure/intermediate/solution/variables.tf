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

variable "owner" {
  description = "EN: Owner tag (required by our custom policy) / FR: Étiquette Owner (exigée par notre politique personnalisée)"
  type        = string
  default     = "platform-team"
}

variable "ssh_public_key" {
  description = "EN: SSH public key content for the VM / FR: Contenu de la clé SSH publique de la VM"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIReplaceWithYourOwnKey you@example"
}
