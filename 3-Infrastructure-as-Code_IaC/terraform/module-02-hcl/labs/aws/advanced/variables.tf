variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# -----------------------------------------------------------------------------
# EN: A COMPLEX TYPE: one object groups everything about the application.
#     optional(type, default) lets callers omit attributes.
# FR: Un TYPE COMPLEXE : un objet regroupe tout ce qui concerne l'application.
#     optional(type, défaut) permet d'omettre des attributs.
# -----------------------------------------------------------------------------
variable "app" {
  description = "EN: Application definition / FR: Définition de l'application"
  type = object({
    name        = string
    environment = string
    owner       = string
    tier        = optional(string, "standard")
    ports       = optional(list(number), [443])
    settings    = optional(map(string), {})
  })

  # EN: Several validation blocks — each with its own clear message.
  # FR: Plusieurs blocs de validation — chacun avec son propre message clair.
  validation {
    condition     = contains(["dev", "staging", "prod"], var.app.environment)
    error_message = "EN: app.environment must be dev, staging or prod. / FR : app.environment doit être dev, staging ou prod."
  }

  validation {
    condition     = contains(["standard", "critical"], var.app.tier)
    error_message = "EN: app.tier must be standard or critical. / FR : app.tier doit être standard ou critical."
  }

  validation {
    condition     = alltrue([for p in var.app.ports : p >= 1 && p <= 65535])
    error_message = "EN: Every port must be between 1 and 65535. / FR : Chaque port doit être entre 1 et 65535."
  }

  validation {
    condition     = length(var.app.ports) == length(distinct(var.app.ports))
    error_message = "EN: Ports must be unique. / FR : Les ports doivent être uniques."
  }
}

variable "vpc_cidr" {
  description = "EN: VPC address range (/16 to /22) / FR: Plage d'adresses du VPC (/16 à /22)"
  type        = string
  default     = "10.42.0.0/16"

  # EN: can() turns an error into false → validates the CIDR syntax.
  # FR: can() transforme une erreur en false → valide la syntaxe CIDR.
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 22
    error_message = "EN: Provide a valid CIDR between /16 and /22. / FR : Fournissez un CIDR valide entre /16 et /22."
  }
}
