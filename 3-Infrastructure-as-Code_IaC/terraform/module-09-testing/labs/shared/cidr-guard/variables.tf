variable "networks" {
  description = "EN: Network name → CIDR / FR: Nom du réseau → CIDR"
  type        = map(string)

  validation {
    condition     = alltrue([for c in values(var.networks) : can(cidrhost(c, 0))])
    error_message = "EN: Every value must be a valid IPv4 CIDR. / FR : Chaque valeur doit être un CIDR IPv4 valide."
  }

  validation {
    condition     = length(var.networks) >= 2
    error_message = "EN: Give at least two networks to compare. / FR : Donnez au moins deux réseaux à comparer."
  }
}
