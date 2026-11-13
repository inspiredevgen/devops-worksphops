# -----------------------------------------------------------------------------
# EN: LOCALS = named expressions computed once and reused. Use them to:
#       • enforce a naming convention in ONE place
#       • build tag maps
#       • translate "environment" into concrete settings
# FR: Les LOCALS = expressions nommées, calculées une fois et réutilisées. Pour :
#       • imposer une convention de nommage à UN seul endroit
#       • construire des maps d'étiquettes
#       • traduire « environment » en paramètres concrets
# -----------------------------------------------------------------------------
locals {
  name_prefix = "${var.project}-${var.environment}"

  # EN: Per-environment settings. Adding "staging" behaviour = edit one map.
  # FR: Paramètres par environnement. Ajouter un comportement « staging » = modifier une map.
  env_settings = {
    dev = {
      versioning         = false
      expiration_days    = 7
      log_retention_days = 7
    }
    staging = {
      versioning         = true
      expiration_days    = 30
      log_retention_days = 30
    }
    prod = {
      versioning         = true
      expiration_days    = 365
      log_retention_days = 90
    }
  }

  settings = local.env_settings[var.environment]

  is_prod = var.environment == "prod"

  # EN: merge(): later maps win on duplicate keys — so mandatory tags go LAST.
  # FR: merge() : les maps suivantes l'emportent sur les clés en double — les
  #     étiquettes obligatoires vont donc EN DERNIER.
  common_tags = merge(
    var.extra_tags,
    {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Course      = "terraform-cloud-engineer"
      Module      = "02-hcl"
    }
  )
}
