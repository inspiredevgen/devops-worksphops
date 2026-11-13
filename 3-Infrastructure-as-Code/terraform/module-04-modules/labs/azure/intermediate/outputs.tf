output "app_network" {
  description = "EN: App network summary / FR: Résumé du réseau applicatif"
  value = {
    vnet_id      = module.app_network.vnet_id
    subnet_cidrs = module.app_network.subnet_cidrs
  }
}

output "shared_network" {
  description = "EN: Shared network summary / FR: Résumé du réseau partagé"
  value = {
    vnet_id      = module.shared_network.vnet_id
    subnet_cidrs = module.shared_network.subnet_cidrs
  }
}
