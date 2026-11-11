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

variable "vnet_cidr" {
  description = "EN: VNet address space / FR: Espace d'adressage du VNet"
  type        = string
  default     = "10.81.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0)) && tonumber(split("/", var.vnet_cidr)[1]) <= 20
    error_message = "EN: A valid CIDR of /20 or larger. / FR : Un CIDR valide de /20 ou plus grand."
  }
}

# EN: Tier name → netnum. Each becomes a /24 via cidrsubnet(vnet_cidr, 8, netnum).
# FR : Nom du niveau → netnum. Chacun devient un /24 via cidrsubnet(vnet_cidr, 8, netnum).
variable "tiers" {
  description = "EN: Subnet tiers and their netnum / FR: Niveaux de sous-réseaux et leur netnum"
  type        = map(number)
  default = {
    web  = 1
    app  = 2
    data = 3
  }
}
