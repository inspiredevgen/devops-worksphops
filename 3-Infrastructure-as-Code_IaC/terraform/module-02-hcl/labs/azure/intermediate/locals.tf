# -----------------------------------------------------------------------------
# EN: LOCALS = named expressions computed once and reused.
# FR: Les LOCALS = expressions nommées, calculées une fois et réutilisées.
# -----------------------------------------------------------------------------
locals {
  name_prefix = "${var.project}-${var.environment}"

  # EN: Per-environment settings. / FR: Paramètres par environnement.
  env_settings = {
    dev = {
      replication        = "LRS"
      log_retention_days = 30
    }
    staging = {
      replication        = "LRS"
      log_retention_days = 60
    }
    prod = {
      replication        = "GRS"
      log_retention_days = 90
    }
  }

  settings = local.env_settings[var.environment]

  # EN: coalesce() returns the first non-null argument → override if given.
  # FR: coalesce() renvoie le premier argument non nul → surcharge si fournie.
  log_retention_days = coalesce(var.log_retention_days_override, local.settings.log_retention_days)

  # EN: Storage account names: 3-24 chars, lowercase letters/digits only.
  #     A chain of functions builds a valid name: remove hyphens, lowercase,
  #     truncate to 20 chars, THEN append the 4-char random suffix (so the
  #     suffix is never cut off).
  # FR: Noms de comptes de stockage : 3 à 24 caractères, minuscules/chiffres.
  #     Une chaîne de fonctions construit un nom valide : retirer les tirets,
  #     mettre en minuscules, tronquer à 20 caractères, PUIS ajouter le
  #     suffixe aléatoire de 4 caractères (qui n'est donc jamais coupé).
  storage_account_name = "${substr(lower(replace("st${var.project}${var.environment}", "-", "")), 0, 20)}${random_string.suffix.result}"

  # EN: merge(): later maps win → mandatory tags go LAST.
  # FR: merge() : les maps suivantes l'emportent → étiquettes obligatoires EN DERNIER.
  common_tags = merge(
    var.extra_tags,
    {
      project     = var.project
      environment = var.environment
      owner       = var.owner
      managedBy   = "terraform"
      course      = "terraform-cloud-engineer"
      module      = "02-hcl"
    }
  )
}
