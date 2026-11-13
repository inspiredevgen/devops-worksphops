# -----------------------------------------------------------------------------
# EN: The module's PUBLIC INTERFACE. Keep it small, typed, validated and
#     documented. Every input you add is a promise to support it.
# FR: L'INTERFACE PUBLIQUE du module. Gardez-la petite, typée, validée et
#     documentée. Chaque entrée ajoutée est une promesse de la maintenir.
# -----------------------------------------------------------------------------

variable "name" {
  description = "EN: Name prefix for every resource / FR: Préfixe de nom de chaque ressource"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "EN: 2-31 chars, lowercase, digits, hyphens. / FR : 2 à 31 caractères, minuscules, chiffres, tirets."
  }
}

variable "vpc_cidr" {
  description = "EN: VPC CIDR, /16 to /24 / FR: CIDR du VPC, /16 à /24"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "EN: Provide a valid CIDR between /16 and /24. / FR : Fournissez un CIDR valide entre /16 et /24."
  }
}

variable "az_count" {
  description = "EN: Number of Availability Zones (1-3) / FR: Nombre de zones de disponibilité (1-3)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "EN: az_count must be 1, 2 or 3. / FR : az_count doit valoir 1, 2 ou 3."
  }
}

variable "tags" {
  description = "EN: Tags added to every resource / FR: Étiquettes ajoutées à chaque ressource"
  type        = map(string)
  default     = {}
}

# EN: v1.1.0 — NEW, OPTIONAL input with a safe default → backward compatible (MINOR bump).
# FR: v1.1.0 — NOUVELLE entrée OPTIONNELLE avec une valeur par défaut sûre → rétrocompatible (version MINEURE).
variable "enable_s3_endpoint" {
  description = "EN: Create a free S3 gateway endpoint / FR: Créer un point de terminaison passerelle S3 gratuit"
  type        = bool
  default     = false
}
