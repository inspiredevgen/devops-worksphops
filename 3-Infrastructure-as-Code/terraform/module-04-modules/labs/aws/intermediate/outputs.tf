output "app_network" {
  description = "EN: App network summary / FR: Résumé du réseau applicatif"
  value = {
    vpc_id          = module.app_network.vpc_id
    azs             = module.app_network.azs
    public_subnets  = module.app_network.public_subnet_ids
    private_subnets = module.app_network.private_subnet_ids
  }
}

output "shared_network" {
  description = "EN: Shared network summary / FR: Résumé du réseau partagé"
  value = {
    vpc_id          = module.shared_network.vpc_id
    azs             = module.shared_network.azs
    public_subnets  = module.shared_network.public_subnet_ids
    private_subnets = module.shared_network.private_subnet_ids
  }
}
