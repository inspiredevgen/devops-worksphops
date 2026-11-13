output "vnet_id" {
  description = "EN: VNet resource ID (from the module) / FR: ID de ressource du VNet (depuis le module)"
  value       = module.vnet.resource_id
}

output "subnet_ids" {
  description = "EN: Subnet IDs by key / FR: ID des sous-réseaux par clé"
  value       = { for k, s in module.vnet.subnets : k => s.resource_id }
}
