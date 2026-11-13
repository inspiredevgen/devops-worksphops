# -----------------------------------------------------------------------------
# EN: Function chains — each line is a small, testable transformation.
#     Try each expression in `terraform console` before reading the result!
# FR: Chaînes de fonctions — chaque ligne est une petite transformation testable.
#     Essayez chaque expression dans `terraform console` avant de lire le résultat !
# -----------------------------------------------------------------------------
locals {
  # EN: "My Shop API" → "my-shop-api" (regex replace + lower + trim + truncate)
  # FR: « My Shop API » → « my-shop-api » (remplacement regex + minuscules + trim + troncature)
  app_slug = substr(trim(lower(replace(var.app.name, "/[^a-zA-Z0-9]+/", "-")), "-"), 0, 24)

  name_prefix = "${local.app_slug}-${var.app.environment}"

  # EN: Read defaults from a YAML file, then let the variable override them.
  # FR: Lire des valeurs par défaut depuis un fichier YAML, puis laisser la variable les surcharger.
  defaults = yamldecode(file("${path.module}/config/defaults.yaml"))
  settings = merge(local.defaults.settings, var.app.settings)

  # EN: Split the VPC into 3 equal subnets (+4 bits each) and name them.
  #     cidrsubnets() + zipmap() — no loops needed.
  # FR: Découper le VPC en 3 sous-réseaux égaux (+4 bits chacun) et les nommer.
  #     cidrsubnets() + zipmap() — aucune boucle nécessaire.
  subnet_cidrs = zipmap(["public", "private", "data"], cidrsubnets(var.vpc_cidr, 4, 4, 4))

  # EN: Pick 2 AZs; slice() keeps the code valid even if a region has more.
  # FR: Choisir 2 zones ; slice() garde le code valide même si la région en a plus.
  azs = slice(sort(data.aws_availability_zones.available.names), 0, 2)

  # EN: lookup() with a default + a conditional on a nested value.
  # FR: lookup() avec valeur par défaut + conditionnelle sur une valeur imbriquée.
  log_retention_days = lookup({ dev = 7, staging = 30, prod = 90 }, var.app.environment, 7)
  is_critical        = var.app.tier == "critical"

  common_tags = {
    App         = local.app_slug
    Environment = var.app.environment
    Owner       = var.app.owner
    Tier        = var.app.tier
    ManagedBy   = "terraform"
    Course      = "terraform-cloud-engineer"
    Module      = "02-hcl"
  }

  # EN: templatefile() renders a template with variables, loops and conditionals.
  # FR: templatefile() génère un fichier à partir d'un modèle avec variables, boucles et conditions.
  rendered_config = templatefile("${path.module}/templates/app-config.yaml.tftpl", {
    name        = local.app_slug
    environment = var.app.environment
    tier        = var.app.tier
    is_critical = local.is_critical
    vpc_cidr    = var.vpc_cidr
    subnets     = local.subnet_cidrs
    ports       = sort([for p in var.app.ports : tostring(p)])
    settings    = local.settings
  })
}
