variable "github_repo" {
  description = "EN: Your practice repository, owner/name / FR: Votre dépôt d'entraînement, propriétaire/nom"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "EN: Use the form owner/name, e.g. jdoe/tf-cicd-lab. / FR : Utilisez la forme propriétaire/nom, ex. jdoe/tf-cicd-lab."
  }
}

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
  description = "EN: Owner tag / FR: Étiquette Owner"
  type        = string
  default     = "platform-team"
}

# EN: The Module 3 state storage (see module-03-state/labs/azure/intermediate/backend.hcl).
# FR : Le stockage d'état du module 3 (voir module-03-state/labs/azure/intermediate/backend.hcl).
variable "state_resource_group" {
  description = "EN: State resource group / FR: Groupe de ressources de l'état"
  type        = string
}

variable "state_storage_account" {
  description = "EN: State storage account / FR: Compte de stockage de l'état"
  type        = string
}

variable "state_container" {
  description = "EN: State container / FR: Conteneur de l'état"
  type        = string
  default     = "tfstate"
}

variable "environments" {
  description = "EN: GitHub environments that may apply / FR: Environnements GitHub autorisés à appliquer"
  type        = set(string)
  default     = ["app", "dev", "prod"]

  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[a-z]{2,4}$", e))])
    error_message = "EN: 2-4 lowercase letters (used in storage account names). / FR : 2 à 4 minuscules (utilisées dans les noms de comptes de stockage)."
  }
}
