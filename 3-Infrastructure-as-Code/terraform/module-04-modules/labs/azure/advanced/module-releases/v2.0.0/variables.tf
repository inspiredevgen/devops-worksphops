# -----------------------------------------------------------------------------
# EN: The module's PUBLIC INTERFACE — small, typed, validated, documented.
# FR: L'INTERFACE PUBLIQUE du module — petite, typée, validée, documentée.
# -----------------------------------------------------------------------------

variable "name" {
  description = "EN: Name suffix for every resource / FR: Suffixe de nom de chaque ressource"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "EN: 2-31 chars, lowercase, digits, hyphens. / FR : 2 à 31 caractères, minuscules, chiffres, tirets."
  }
}

variable "resource_group_name" {
  description = "EN: Existing resource group / FR: Groupe de ressources existant"
  type        = string
}

variable "location" {
  description = "EN: Azure region / FR: Région Azure"
  type        = string
}

variable "vnet_cidr" {
  description = "EN: VNet CIDR, /16 to /20 (subnets are /24 to /28) / FR: CIDR du VNet, /16 à /20 (sous-réseaux /24 à /28)"
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0)) && tonumber(split("/", var.vnet_cidr)[1]) >= 16 && tonumber(split("/", var.vnet_cidr)[1]) <= 20
    error_message = "EN: Provide a valid CIDR between /16 and /20. / FR : Fournissez un CIDR valide entre /16 et /20."
  }
}

variable "subnet_names" {
  description = "EN: Subnets to create, in order (each gets the next /+8 block) / FR: Sous-réseaux à créer, dans l'ordre (chacun reçoit le bloc /+8 suivant)"
  type        = list(string)
  default     = ["app", "data"]

  validation {
    condition     = length(var.subnet_names) > 0 && length(var.subnet_names) == length(distinct(var.subnet_names))
    error_message = "EN: At least one subnet; names must be unique. / FR : Au moins un sous-réseau ; noms uniques."
  }
}

variable "tags" {
  description = "EN: Tags added to every resource / FR: Étiquettes ajoutées à chaque ressource"
  type        = map(string)
  default     = {}
}

# EN: v1.1.0 — NEW, OPTIONAL input with a safe default → backward compatible (MINOR bump).
# FR: v1.1.0 — NOUVELLE entrée OPTIONNELLE avec une valeur par défaut sûre → rétrocompatible (version MINEURE).
variable "service_endpoints" {
  description = "EN: Service endpoints enabled on every subnet, e.g. [\"Microsoft.Storage\"] / FR: Points de terminaison de service activés sur chaque sous-réseau, ex. [\"Microsoft.Storage\"]"
  type        = list(string)
  default     = []
}
