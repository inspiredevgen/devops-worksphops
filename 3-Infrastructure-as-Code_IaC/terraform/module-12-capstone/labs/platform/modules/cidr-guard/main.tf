# =============================================================================
# cidr-guard: detects overlapping CIDRs (the Module 8 logic, now as a tested module)
# cidr-guard : détecte les CIDR qui se chevauchent (la logique du module 8, en module testé)
# =============================================================================

locals {
  names = sort(keys(var.networks))

  ranges = {
    for k, c in var.networks : k => {
      start = sum([for i, octet in split(".", cidrhost(c, 0)) : tonumber(octet) * pow(256, 3 - i)])
      size  = pow(2, 32 - tonumber(split("/", c)[1]))
    }
  }

  # EN: Every unordered pair (a, b) with a before b alphabetically, kept only if the ranges intersect.
  # FR : Chaque paire non ordonnée (a, b) avec a avant b, conservée seulement si les plages se croisent.
  overlaps = flatten([
    for i, a in local.names : [
      for j, b in local.names : "${a}<->${b}"
      if j > i
      && local.ranges[a].start < local.ranges[b].start + local.ranges[b].size
      && local.ranges[b].start < local.ranges[a].start + local.ranges[a].size
    ]
  ])
}

output "overlaps" {
  description = "EN: Overlapping pairs (empty = good) / FR: Paires qui se chevauchent (vide = bon)"
  value       = local.overlaps
}

output "networks" {
  description = "EN: The validated networks / FR: Les réseaux validés"
  value       = var.networks

  # EN: An output precondition: consumers can only read this if there is no overlap.
  # FR : Une précondition de sortie : on ne peut lire cette valeur que s'il n'y a aucun chevauchement.
  precondition {
    condition     = !var.fail_on_overlap || length(local.overlaps) == 0
    error_message = "EN: Overlapping networks: ${join(", ", local.overlaps)}. / FR : Réseaux qui se chevauchent : ${join(", ", local.overlaps)}."
  }
}
