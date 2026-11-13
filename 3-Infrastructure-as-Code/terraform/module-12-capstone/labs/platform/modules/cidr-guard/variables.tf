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

# EN: Added for the capstone: a root that wants to own the check (and test it) can turn this off.
# FR : Ajouté pour le projet final : une racine qui veut porter la vérification (et la tester) peut la désactiver.
variable "fail_on_overlap" {
  description = "EN: Fail this module's output on overlap / FR: Faire échouer la sortie de ce module en cas de chevauchement"
  type        = bool
  default     = true
}
