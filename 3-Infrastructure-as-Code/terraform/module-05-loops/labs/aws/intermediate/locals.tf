# -----------------------------------------------------------------------------
# EN: `for` EXPRESSIONS transform collections. Try each one in `terraform console`.
# FR: Les expressions `for` transforment des collections. Essayez chacune dans `terraform console`.
# -----------------------------------------------------------------------------
locals {
  azs = sort(data.aws_availability_zones.available.names)

  # EN: FILTER with `if` → only public subnets. Keys come from var.subnets,
  #     so they are KNOWN at plan time (a requirement for for_each).
  # FR: FILTRER avec `if` → seulement les sous-réseaux publics. Les clés viennent
  #     de var.subnets : elles sont CONNUES au plan (exigence de for_each).
  public_subnet_keys = toset([for k, s in var.subnets : k if s.public])

  # EN: Map an access level to an AWS-managed policy.
  # FR: Associer un niveau d'accès à une politique gérée par AWS.
  base_policy = {
    readonly = "ReadOnlyAccess"
    power    = "PowerUserAccess"
  }

  # EN: NESTED LOOP + flatten(): teams × policies → one flat list of
  #     attachments, each with a UNIQUE, STABLE key "team/policy".
  # FR: BOUCLE IMBRIQUÉE + flatten() : équipes × politiques → une liste plate
  #     d'attachements, chacun avec une clé UNIQUE et STABLE « équipe/politique ».
  team_policy_attachments = flatten([
    for team, cfg in var.teams : [
      for policy in concat([local.base_policy[cfg.access]], cfg.extra_policies) : {
        key    = "${team}/${policy}"
        team   = team
        policy = policy
      }
    ]
  ])
}
