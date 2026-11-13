# EN: Every switch below breaks one policy. Flip them one at a time and run the gate.
# FR : Chaque interrupteur ci-dessous enfreint une politique. Basculez-les un par un et lancez la porte.

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
  description = "EN: Owner tag; \"\" breaks tags.rego / FR: Étiquette Owner ; \"\" enfreint tags.rego"
  type        = string
  default     = "platform-team"
}

variable "ssh_from_internet" {
  description = "EN: true breaks network.rego / FR: true enfreint network.rego"
  type        = bool
  default     = false
}

variable "vm_size" {
  description = "EN: e.g. Standard_D64s_v5 breaks compute.rego / FR: ex. Standard_D64s_v5 enfreint compute.rego"
  type        = string
  default     = "Standard_B1s"
}

variable "ssh_public_key" {
  description = "EN: SSH public key CONTENT / FR: CONTENU de la clé SSH publique"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlanOnlyPlaceholderKeyForTheGateLab00000 plan-only"
}
