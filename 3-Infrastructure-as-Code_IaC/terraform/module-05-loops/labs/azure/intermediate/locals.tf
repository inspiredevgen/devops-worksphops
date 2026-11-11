# -----------------------------------------------------------------------------
# EN: `for` EXPRESSIONS — try each one in `terraform console`.
# FR: Expressions `for` — essayez chacune dans `terraform console`.
# -----------------------------------------------------------------------------
locals {
  tags = {
    course = "terraform-cloud-engineer"
    module = "05-loops"
  }

  # EN: FILTER: only subnets that should get an NSG.
  # FR: FILTRE : seulement les sous-réseaux qui doivent recevoir un NSG.
  nsg_subnets = { for k, s in var.subnets : k => s if s.nsg }

  # EN: NESTED LOOP + flatten(): { team => [envs] } → [{ key, team, env }, …]
  # FR: BOUCLE IMBRIQUÉE + flatten() : { équipe => [envs] } → [{ key, team, env }, …]
  team_envs = flatten([
    for team, envs in var.team_environments : [
      for env in envs : {
        key  = "${team}-${env}"
        team = team
        env  = env
      }
    ]
  ])
}
