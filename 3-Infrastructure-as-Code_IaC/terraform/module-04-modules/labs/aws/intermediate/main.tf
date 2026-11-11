# -----------------------------------------------------------------------------
# Lab 4.I-AWS — Writing and reusing your own module
# Lab 4.I-AWS — Écrire et réutiliser votre propre module
#
# EN: The SAME module is called twice with different inputs → two isolated
#     networks from one tested piece of code. Cost: $0 (no NAT).
# FR: Le MÊME module est appelé deux fois avec des entrées différentes → deux
#     réseaux isolés à partir d'un seul code testé. Coût : 0 $ (pas de NAT).
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "EN: AWS region / FR: Région AWS"
  type        = string
  default     = "ca-central-1"
}

module "app_network" {
  source = "./modules/network" # EN: LOCAL path — no version argument / FR : chemin LOCAL — pas d'argument version

  name       = "tf-lab-m04-app"
  cidr_block = "10.60.0.0/16"
  az_count   = 2

  tags = {
    Network = "app"
  }
}

module "shared_network" {
  source = "./modules/network"

  name       = "tf-lab-m04-shared"
  cidr_block = "10.61.0.0/20"
  az_count   = 1

  tags = {
    Network = "shared"
  }
}

# EN: Root resources consume module outputs.
# FR: Les ressources racines utilisent les sorties des modules.
resource "aws_security_group" "app_web" {
  name_prefix = "tf-lab-m04-app-web-"
  description = "Web tier in the app network"
  vpc_id      = module.app_network.vpc_id
}
