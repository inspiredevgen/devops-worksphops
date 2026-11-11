variable "subscription_id" {
  description = "EN: Subscription ID (or ARM_SUBSCRIPTION_ID) / FR: ID d'abonnement (ou ARM_SUBSCRIPTION_ID)"
  type        = string
  default     = null
}

variable "location" {
  type    = string
  default = "canadacentral"
}

variable "hub_cidr" {
  type    = string
  default = "10.95.0.0/16"
}

variable "spokes" {
  description = "EN: Spoke name → CIDR / FR: Nom du rayon → CIDR"
  type        = map(string)
  default = {
    app  = "10.96.0.0/16"
    data = "10.97.0.0/16"
  }
}

# EN: Azure Firewall (Basic) is the ONLY expensive part of this lab: roughly $0.40/hour + data.
#     Leave it off for parts 1-2; turn it on for part 3 and destroy within the hour.
# FR : Azure Firewall (Basic) est la SEULE partie coûteuse de ce lab : environ 0,40 $/heure + données.
#     Laissez-le désactivé pour les parties 1-2 ; activez-le pour la partie 3 et détruisez dans l'heure.
variable "enable_firewall" {
  description = "EN: Deploy Azure Firewall Basic + spoke-to-spoke routes / FR: Déployer Azure Firewall Basic + routes entre rayons"
  type        = bool
  default     = false
}
