# -----------------------------------------------------------------------------
# Lab 3.I-AZ (part 2) — An application that stores its state remotely
# Lab 3.I-AZ (partie 2) — Une application qui stocke son état à distance
#
# EN: time_sleep keeps `apply` running long enough to SEE the blob lease
#     (lock) from a second terminal. Cost: $0.
# FR: time_sleep fait durer `apply` assez longtemps pour VOIR le bail (verrou)
#     du blob depuis un second terminal. Coût : 0 $.
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

variable "release" {
  description = "EN: Release label — change it to trigger a new apply / FR: Étiquette de version — changez-la pour déclencher un nouvel apply"
  type        = string
  default     = "v1"
}

variable "sleep_duration" {
  description = "EN: How long apply holds the lock / FR: Durée pendant laquelle apply garde le verrou"
  type        = string
  default     = "90s"
}

resource "azurerm_resource_group" "demo" {
  name     = "rg-tf-lab-m03-remote"
  location = var.location

  tags = {
    course  = "terraform-cloud-engineer"
    module  = "03-state"
    release = var.release
  }
}

# EN: Re-created whenever `release` changes → each release apply waits.
# FR: Recréé à chaque changement de `release` → chaque apply de version attend.
resource "time_sleep" "hold_lock" {
  create_duration = var.sleep_duration

  triggers = {
    release = var.release
  }

  depends_on = [azurerm_resource_group.demo]
}

output "release" {
  description = "EN: Current release tag / FR: Étiquette de version actuelle"
  value       = azurerm_resource_group.demo.tags["release"]
}
