# -----------------------------------------------------------------------------
# Lab 4.B-AWS — Consuming a public Registry module
# Lab 4.B-AWS — Utiliser un module public du Registry
#
# EN: terraform-aws-modules/vpc is one of the most-used modules in the world.
#     ~10 lines of input replace ~20 resources you'd otherwise write by hand.
#     Cost: $0 — NAT gateways are DISABLED (they cost ~$35/month each).
# FR: terraform-aws-modules/vpc est l'un des modules les plus utilisés au monde.
#     ~10 lignes d'entrées remplacent ~20 ressources à écrire à la main.
#     Coût : 0 $ — les passerelles NAT sont DÉSACTIVÉES (~35 $/mois chacune).
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(sort(data.aws_availability_zones.available.names), 0, 2)
}

module "vpc" {
  # EN: Registry source: <NAMESPACE>/<NAME>/<PROVIDER>
  # FR: Source Registry : <ESPACE_DE_NOMS>/<NOM>/<PROVIDER>
  source = "terraform-aws-modules/vpc/aws"

  # EN: ALWAYS pin registry modules. "~> 6.6" = 6.6 or newer, but never 7.0.
  # FR: Épinglez TOUJOURS les modules du Registry. « ~> 6.6 » = 6.6 ou plus, jamais 7.0.
  version = "~> 6.6"

  # EN: Module INPUTS (the module's variables).
  # FR: ENTRÉES du module (ses variables).
  name = "tf-lab-m04-registry"
  cidr = "10.50.0.0/16"
  azs  = local.azs

  public_subnets  = ["10.50.0.0/24", "10.50.1.0/24"]
  private_subnets = ["10.50.10.0/24", "10.50.11.0/24"]

  enable_nat_gateway   = false # EN: cost control! / FR : contrôle des coûts !
  enable_dns_hostnames = true

  tags = {
    Lab = "4.B"
  }
}

# EN: Consuming a module OUTPUT: module.<NAME>.<OUTPUT>
# FR: Utiliser une SORTIE de module : module.<NOM>.<SORTIE>
resource "aws_security_group" "web" {
  name_prefix = "tf-lab-m04-web-"
  description = "Web tier - uses the VPC created by the registry module"
  vpc_id      = module.vpc.vpc_id
}
