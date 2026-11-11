# -----------------------------------------------------------------------------
# Lab 3.B-AZ — Inside the state file
# Lab 3.B-AZ — À l'intérieur du fichier d'état
#
# EN: Three tiny, free resources so you can focus on what Terraform RECORDS.
# FR: Trois ressources minuscules et gratuites pour vous concentrer sur ce que
#     Terraform ENREGISTRE.
# -----------------------------------------------------------------------------

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

# EN: A random name — its value exists ONLY in state (no cloud API).
# FR: Un nom aléatoire — sa valeur n'existe QUE dans l'état (aucune API cloud).
resource "random_pet" "app" {
  length = 2
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m03-${random_pet.app.id}"
  location = var.location

  tags = {
    course = "terraform-cloud-engineer"
    module = "03-state"
  }
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${random_pet.app.id}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
}

output "app_name" {
  description = "EN: Generated app name / FR: Nom d'application généré"
  value       = random_pet.app.id
}

output "resource_group_name" {
  description = "EN: Resource group / FR: Groupe de ressources"
  value       = azurerm_resource_group.lab.name
}

output "identity_principal_id" {
  description = "EN: Identity principal ID / FR: ID du principal de l'identité"
  value       = azurerm_user_assigned_identity.app.principal_id
}
