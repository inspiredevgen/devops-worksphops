# EN: Minimal working example — every published module should have one.
#     Also used by automated tests (Module 9).
# FR: Exemple minimal fonctionnel — tout module publié devrait en avoir un.
#     Sert aussi aux tests automatisés (module 9).

provider "aws" {
  region = "ca-central-1"
}

module "network" {
  source = "../.."

  name       = "example"
  cidr_block = "10.99.0.0/16"
  az_count   = 2
}

output "vpc_id" {
  value = module.network.vpc_id
}
