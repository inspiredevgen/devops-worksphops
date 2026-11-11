variable "name_prefix" {
  description = "EN: Storage name prefix, lowercase letters/digits (a 6-char suffix is added) / FR: Préfixe, minuscules/chiffres (un suffixe de 6 caractères est ajouté)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,18}$", var.name_prefix))
    error_message = "EN: 3-18 lowercase letters or digits. / FR : 3 à 18 minuscules ou chiffres."
  }
}

variable "resource_group_name" {
  description = "EN: Resource group / FR: Groupe de ressources"
  type        = string
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
}

# EN: Empty list = open network access. Non-empty = deny everything except
#     these subnets (they need the Microsoft.Storage service endpoint) and
#     the admin IPs.
# FR: Liste vide = accès réseau ouvert. Non vide = tout refuser sauf ces
#     sous-réseaux (ils ont besoin du point Microsoft.Storage) et les IP admin.
variable "allowed_subnet_ids" {
  description = "EN: Subnets allowed to reach the account / FR: Sous-réseaux autorisés à joindre le compte"
  type        = list(string)
  default     = []
}

variable "admin_ip_rules" {
  description = "EN: Public IPs (no /32) always allowed / FR: IP publiques (sans /32) toujours autorisées"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "EN: Extra tags / FR: Étiquettes supplémentaires"
  type        = map(string)
  default     = {}
}
