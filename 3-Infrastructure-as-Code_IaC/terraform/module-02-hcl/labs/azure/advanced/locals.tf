# -----------------------------------------------------------------------------
# EN: Function chains — try each expression in `terraform console` first!
# FR: Chaînes de fonctions — essayez chaque expression dans `terraform console` d'abord !
# -----------------------------------------------------------------------------
locals {
  # EN: "My Shop API!" → "my-shop-api"
  # FR: « My Shop API! » → « my-shop-api »
  app_slug = substr(trim(lower(replace(var.app.name, "/[^a-zA-Z0-9]+/", "-")), "-"), 0, 24)

  name_prefix = "${local.app_slug}-${var.app.environment}"

  # EN: Storage names allow no hyphens → strip them, truncate, append suffix.
  # FR: Les noms de stockage n'acceptent pas de tirets → les retirer, tronquer, ajouter le suffixe.
  storage_account_name = "${substr(replace("st${local.app_slug}${var.app.environment}", "-", ""), 0, 20)}${random_string.suffix.result}"

  # EN: YAML defaults, overridden by the variable.
  # FR: Valeurs YAML par défaut, surchargées par la variable.
  defaults = yamldecode(file("${path.module}/config/defaults.yaml"))
  settings = merge(local.defaults.settings, var.app.settings)

  # EN: 3 equal subnets (+4 bits each), named with zipmap().
  # FR: 3 sous-réseaux égaux (+4 bits chacun), nommés avec zipmap().
  subnet_cidrs = zipmap(["public", "private", "data"], cidrsubnets(var.vnet_cidr, 4, 4, 4))

  is_critical = var.app.tier == "critical"

  # EN: Critical apps get geo-redundant storage.
  # FR: Les applications critiques obtiennent un stockage géo-redondant.
  replication = local.is_critical ? "GRS" : "LRS"

  common_tags = {
    app         = local.app_slug
    environment = var.app.environment
    owner       = var.app.owner
    tier        = var.app.tier
    managedBy   = "terraform"
    course      = "terraform-cloud-engineer"
    module      = "02-hcl"
  }

  rendered_config = templatefile("${path.module}/templates/app-config.yaml.tftpl", {
    name        = local.app_slug
    environment = var.app.environment
    tier        = var.app.tier
    is_critical = local.is_critical
    vpc_cidr    = var.vnet_cidr
    subnets     = local.subnet_cidrs
    ports       = sort([for p in var.app.ports : tostring(p)])
    settings    = local.settings
  })
}
