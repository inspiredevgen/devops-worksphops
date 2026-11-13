# =============================================================================
# The capstone's address plan, CHECKED. No provider, no credentials: `terraform test` runs anywhere.
# Le plan d'adressage du projet final, VÉRIFIÉ. Sans provider ni identifiants : `terraform test` tourne partout.
# EN: Add every network you might ever connect (on-premises, VPN, other projects).
# FR : Ajoutez chaque réseau que vous pourriez un jour relier (site local, VPN, autres projets).
# =============================================================================
terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

variable "networks" {
  description = "EN: Every network in the estate / FR: Chaque réseau du parc"
  type        = map(string)
  default = {
    aws-dev     = "10.110.0.0/16"
    aws-prod    = "10.111.0.0/16"
    azure-dev   = "10.120.0.0/16"
    azure-prod  = "10.121.0.0/16"
    on-premises = "10.0.0.0/16"
    vpn-clients = "172.16.0.0/22"
  }
}

module "guard" {
  source          = "../../modules/cidr-guard"
  networks        = var.networks
  fail_on_overlap = false # EN: the root output below owns the check / FR : la sortie racine ci-dessous porte la vérification
}

# EN: The ROOT output carries its own precondition, so tests (and CI) can expect it to fail.
# FR : La sortie RACINE porte sa propre précondition : les tests (et la CI) peuvent s'attendre à son échec.
output "networks" {
  value = var.networks

  precondition {
    condition     = length(module.guard.overlaps) == 0
    error_message = "EN: Overlapping networks: ${join(", ", module.guard.overlaps)}. / FR : Réseaux qui se chevauchent : ${join(", ", module.guard.overlaps)}."
  }
}
