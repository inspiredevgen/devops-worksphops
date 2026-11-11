# EN: Each variable is designed to trigger a DIFFERENT kind of plan action.
# FR: Chaque variable est conçue pour déclencher un type d'action DIFFÉRENT dans le plan.

variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

# EN: Changing this → resource group location changes → REPLACE (-/+) of EVERYTHING.
# FR: Modifier ceci → l'emplacement du groupe change → REMPLACEMENT (-/+) de TOUT.
variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
  default     = "canadacentral"
}

# EN: Changing this → only tags change → UPDATE IN-PLACE (~).
# FR: Modifier ceci → seules les étiquettes changent → MISE À JOUR SUR PLACE (~).
variable "environment" {
  description = "EN: Environment tag / FR: Étiquette d'environnement"
  type        = string
  default     = "dev"
}

# EN: LRS → GRS is supported in-place by Azure → UPDATE IN-PLACE (~).
# FR: LRS → GRS est pris en charge sur place par Azure → MISE À JOUR SUR PLACE (~).
variable "replication_type" {
  description = "EN: Storage replication / FR: Réplication du stockage"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS"], var.replication_type)
    error_message = "EN: Use LRS or GRS in this lab. / FR : Utilisez LRS ou GRS dans ce lab."
  }
}

variable "welcome_message" {
  description = "EN: Content of README.txt / FR: Contenu de README.txt"
  type        = string
  default     = "Hello from Terraform! / Bonjour de Terraform !"
}
