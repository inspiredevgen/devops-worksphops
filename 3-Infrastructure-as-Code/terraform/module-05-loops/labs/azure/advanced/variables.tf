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

# -----------------------------------------------------------------------------
# EN: SECURITY POLICY AS DATA. Each tier becomes an Application Security
#     Group (ASG); each rule allows ONE port to that tier from EXACTLY ONE of:
#       source_cidr  — an IP range
#       source_tag   — an Azure service tag ("Internet", "VirtualNetwork", …)
#       source_tier  — another tier (its ASG)
#     Priorities are COMPUTED from the rule order — no manual numbering.
# FR: LA POLITIQUE DE SÉCURITÉ COMME DONNÉES. Chaque niveau devient un groupe
#     de sécurité d'application (ASG) ; chaque règle autorise UN port vers ce
#     niveau depuis EXACTEMENT UNE source :
#       source_cidr  — une plage d'IP
#       source_tag   — une étiquette de service Azure (« Internet », « VirtualNetwork »…)
#       source_tier  — un autre niveau (son ASG)
#     Les priorités sont CALCULÉES à partir de l'ordre — aucune numérotation manuelle.
# -----------------------------------------------------------------------------
variable "tiers" {
  description = "EN: Tiers and their inbound rules / FR: Niveaux et leurs règles entrantes"
  type = map(list(object({
    name        = string
    port        = number
    protocol    = optional(string, "Tcp")
    source_cidr = optional(string)
    source_tag  = optional(string)
    source_tier = optional(string)
  })))

  default = {
    web = [
      { name = "https-internet", port = 443, source_tag = "Internet" },
    ]
    app = [
      { name = "app-from-web", port = 8080, source_tier = "web" },
    ]
    db = [
      { name = "sql-from-app", port = 1433, source_tier = "app" },
      { name = "sql-from-vpn", port = 1433, source_cidr = "10.8.0.0/16" },
    ]
  }

  validation {
    condition = alltrue(flatten([
      for rules in values(var.tiers) : [
        for r in rules : length(compact([r.source_cidr, r.source_tag, r.source_tier])) == 1
      ]
    ]))
    error_message = "EN: Each rule needs exactly one of source_cidr, source_tag, source_tier. / FR : Chaque règle exige exactement une source parmi source_cidr, source_tag, source_tier."
  }

  validation {
    condition = alltrue(flatten([
      for rules in values(var.tiers) : [
        for r in rules : r.source_tier == null || contains(keys(var.tiers), r.source_tier == null ? "" : r.source_tier)
      ]
    ]))
    error_message = "EN: source_tier must be the key of another tier. / FR : source_tier doit être la clé d'un autre niveau."
  }
}

# -----------------------------------------------------------------------------
# EN: Blob lifecycle rules — rendered with an OPTIONAL dynamic block.
# FR: Règles de cycle de vie des blobs — rendues avec un bloc dynamic OPTIONNEL.
# -----------------------------------------------------------------------------
variable "lifecycle_rules" {
  description = "EN: Storage management policy rules / FR: Règles de stratégie de gestion du stockage"
  type = list(object({
    name                       = string
    prefix                     = string
    cool_after_days            = optional(number)
    archive_after_days         = optional(number)
    delete_after_days          = optional(number)
    delete_versions_after_days = optional(number)
  }))

  default = [
    { name = "logs", prefix = "logs/", cool_after_days = 30, archive_after_days = 90, delete_after_days = 365 },
    { name = "tmp", prefix = "tmp/", delete_after_days = 7 },
    { name = "versions", prefix = "data/", delete_versions_after_days = 30 },
  ]
}
