# EN: Outputs = the module's RETURN VALUES. Expose IDs, not whole objects.
# FR: Les sorties = les VALEURS DE RETOUR du module. Exposez des ID, pas des objets entiers.

output "vnet_id" {
  description = "EN: VNet ID / FR: ID du VNet"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "EN: VNet name / FR: Nom du VNet"
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "EN: Subnet IDs by name / FR: ID des sous-réseaux par nom"
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "subnet_cidrs" {
  description = "EN: Subnet CIDRs by name / FR: CIDR des sous-réseaux par nom"
  value       = local.subnets
}

output "nsg_ids" {
  description = "EN: NSG IDs by subnet name / FR: ID des NSG par nom de sous-réseau"
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
}
