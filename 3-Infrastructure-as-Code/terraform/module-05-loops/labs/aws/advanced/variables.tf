variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

# -----------------------------------------------------------------------------
# EN: SECURITY POLICY AS DATA. Each tier is a security group; each rule
#     allows ONE port from EITHER a CIDR OR another tier (source_sg).
#     Reviewers read this map, not 40 resource blocks.
# FR: LA POLITIQUE DE SÉCURITÉ COMME DONNÉES. Chaque niveau est un groupe de
#     sécurité ; chaque règle autorise UN port depuis SOIT un CIDR, SOIT un
#     autre niveau (source_sg). Les réviseurs lisent cette map, pas 40 blocs.
# -----------------------------------------------------------------------------
variable "security_groups" {
  description = "EN: Tiers and their ingress rules / FR: Niveaux et leurs règles entrantes"
  type = map(object({
    description = string
    ingress = optional(list(object({
      name      = string
      port      = number
      to_port   = optional(number)
      protocol  = optional(string, "tcp")
      cidr      = optional(string)
      source_sg = optional(string)
    })), [])
  }))

  default = {
    web = {
      description = "Public web tier"
      ingress = [
        { name = "https-internet", port = 443, cidr = "0.0.0.0/0" },
        { name = "http-internet", port = 80, cidr = "0.0.0.0/0" },
      ]
    }
    app = {
      description = "Application tier"
      ingress = [
        { name = "app-from-web", port = 8080, source_sg = "web" },
      ]
    }
    db = {
      description = "Database tier"
      ingress = [
        { name = "postgres-from-app", port = 5432, source_sg = "app" },
        { name = "postgres-from-vpn", port = 5432, cidr = "10.8.0.0/16" },
      ]
    }
  }

  # EN: Exactly one source per rule.
  # FR: Exactement une source par règle.
  validation {
    condition = alltrue(flatten([
      for sg in values(var.security_groups) : [
        for r in sg.ingress : (r.cidr == null) != (r.source_sg == null)
      ]
    ]))
    error_message = "EN: Each rule needs exactly one of cidr or source_sg. / FR : Chaque règle exige exactement un de cidr ou source_sg."
  }

  # EN: source_sg must reference an existing tier.
  # FR: source_sg doit référencer un niveau existant.
  validation {
    condition = alltrue(flatten([
      for sg in values(var.security_groups) : [
        for r in sg.ingress : r.source_sg == null || contains(keys(var.security_groups), r.source_sg == null ? "" : r.source_sg)
      ]
    ]))
    error_message = "EN: source_sg must be the key of another security group. / FR : source_sg doit être la clé d'un autre groupe de sécurité."
  }

  # EN: Rule names must be unique within a tier (they become for_each keys).
  # FR: Les noms de règles doivent être uniques dans un niveau (ils deviennent des clés for_each).
  validation {
    condition = alltrue([
      for sg in values(var.security_groups) : length(distinct([for r in sg.ingress : r.name])) == length(sg.ingress)
    ])
    error_message = "EN: Duplicate rule name within a tier. / FR : Nom de règle en double dans un niveau."
  }
}

# -----------------------------------------------------------------------------
# EN: Lifecycle policy as data — rendered with NESTED dynamic blocks.
# FR: Politique de cycle de vie comme données — rendue avec des blocs dynamic IMBRIQUÉS.
# -----------------------------------------------------------------------------
variable "lifecycle_rules" {
  description = "EN: S3 lifecycle rules / FR: Règles de cycle de vie S3"
  type = list(object({
    id                     = string
    prefix                 = optional(string, "")
    transitions            = optional(list(object({ days = number, storage_class = string })), [])
    expire_days            = optional(number)
    noncurrent_expire_days = optional(number)
  }))

  default = [
    {
      id     = "logs"
      prefix = "logs/"
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" },
      ]
      expire_days = 365
    },
    {
      id          = "tmp"
      prefix      = "tmp/"
      expire_days = 7
    },
    {
      id                     = "old-versions"
      noncurrent_expire_days = 30
    },
  ]
}
