variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

variable "vpc_cidr" {
  description = "EN: VPC CIDR (/16) / FR: CIDR du VPC (/16)"
  type        = string
  default     = "10.63.0.0/16"
}

# -----------------------------------------------------------------------------
# EN: A MAP with stable KEYS: each subnet is identified by its NAME, and its
#     CIDR by an explicit netnum — never by its position. Add/remove any
#     entry and only that subnet is created/destroyed.
# FR: Une MAP à CLÉS stables : chaque sous-réseau est identifié par son NOM,
#     et son CIDR par un netnum explicite — jamais par sa position. Ajoutez ou
#     retirez une entrée : seul ce sous-réseau est créé/détruit.
# -----------------------------------------------------------------------------
variable "subnets" {
  description = "EN: Subnets keyed by name / FR: Sous-réseaux indexés par nom"
  type = map(object({
    netnum   = number                # EN: /24 index inside the VPC / FR: index /24 dans le VPC
    az_index = number                # EN: 0, 1 or 2 / FR: 0, 1 ou 2
    public   = optional(bool, false) # EN: route to the Internet Gateway? / FR: route vers la passerelle Internet ?
  }))

  default = {
    "web-a" = { netnum = 0, az_index = 0, public = true }
    "web-b" = { netnum = 1, az_index = 1, public = true }
    "app-a" = { netnum = 10, az_index = 0 }
    "app-b" = { netnum = 11, az_index = 1 }
    "db-a"  = { netnum = 20, az_index = 0 }
    "db-b"  = { netnum = 21, az_index = 1 }
  }

  validation {
    condition     = length(distinct([for s in values(var.subnets) : s.netnum])) == length(var.subnets)
    error_message = "EN: Every netnum must be unique (no overlapping CIDRs). / FR : Chaque netnum doit être unique (pas de CIDR qui se chevauchent)."
  }

  validation {
    condition     = alltrue([for s in values(var.subnets) : s.az_index >= 0 && s.az_index <= 2 && s.netnum >= 0 && s.netnum <= 255])
    error_message = "EN: az_index 0-2 and netnum 0-255. / FR : az_index 0-2 et netnum 0-255."
  }

  validation {
    condition     = alltrue([for k in keys(var.subnets) : can(regex("^[a-z]+-[a-z0-9]+$", k))])
    error_message = "EN: Keys must look like <tier>-<suffix>, e.g. web-a. / FR : Les clés doivent ressembler à <tier>-<suffixe>, ex. web-a."
  }
}

# -----------------------------------------------------------------------------
# EN: Teams → IAM roles. Each team gets a base policy from its access level
#     plus optional extra AWS-managed policies. Role names use the "tf-"
#     prefix required by the course role (Module 0).
# FR: Équipes → rôles IAM. Chaque équipe reçoit une politique de base selon
#     son niveau d'accès plus des politiques gérées AWS optionnelles. Les noms
#     de rôles utilisent le préfixe « tf- » exigé par le rôle du cours (module 0).
# -----------------------------------------------------------------------------
variable "teams" {
  description = "EN: Teams and their access / FR: Équipes et leurs accès"
  type = map(object({
    access         = string
    extra_policies = optional(list(string), [])
  }))

  default = {
    platform  = { access = "power" }
    analytics = { access = "readonly", extra_policies = ["AmazonAthenaFullAccess"] }
    support   = { access = "readonly" }
  }

  validation {
    condition     = alltrue([for t in values(var.teams) : contains(["readonly", "power"], t.access)])
    error_message = "EN: access must be readonly or power. / FR : access doit valoir readonly ou power."
  }
}
