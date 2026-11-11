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
  description = "EN: VNet CIDR (/16) / FR: CIDR du VNet (/16)"
  type        = string
  default     = "10.83.0.0/16"
}

# -----------------------------------------------------------------------------
# EN: A MAP with stable KEYS and explicit netnums — this fixes the
#     list-ordering trap from Module 4.
# FR: Une MAP à CLÉS stables et netnum explicites — cela corrige le piège de
#     l'ordre des listes du module 4.
# -----------------------------------------------------------------------------
variable "subnets" {
  description = "EN: Subnets keyed by name / FR: Sous-réseaux indexés par nom"
  type = map(object({
    netnum            = number
    nsg               = optional(bool, true)
    service_endpoints = optional(list(string), [])
  }))

  default = {
    web  = { netnum = 0 }
    app  = { netnum = 1, service_endpoints = ["Microsoft.Storage"] }
    data = { netnum = 2, service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"] }
    # EN: Azure requires this exact name for VPN/ExpressRoute gateways, and does NOT support an NSG on it.
    # FR: Azure exige ce nom exact pour les passerelles VPN/ExpressRoute, et n'y prend PAS en charge de NSG.
    GatewaySubnet = { netnum = 254, nsg = false }
  }

  validation {
    condition     = length(distinct([for s in values(var.subnets) : s.netnum])) == length(var.subnets)
    error_message = "EN: Every netnum must be unique. / FR : Chaque netnum doit être unique."
  }
}

# -----------------------------------------------------------------------------
# EN: Teams and the environments each one needs an identity for.
# FR: Les équipes et les environnements pour lesquels chacune a besoin d'une identité.
# -----------------------------------------------------------------------------
variable "team_environments" {
  description = "EN: { team => [environments] } / FR: { équipe => [environnements] }"
  type        = map(list(string))

  default = {
    platform  = ["dev", "staging", "prod"]
    analytics = ["dev", "prod"]
    support   = ["prod"]
  }

  validation {
    condition     = alltrue([for t in keys(var.team_environments) : can(regex("^[a-z0-9]+$", t))])
    error_message = "EN: Team names: lowercase letters and digits only (no hyphens). / FR : Noms d'équipe : minuscules et chiffres uniquement (sans tiret)."
  }
}
