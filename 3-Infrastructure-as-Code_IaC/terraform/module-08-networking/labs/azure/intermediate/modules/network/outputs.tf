output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "cidr" {
  value = var.cidr
}

output "subnet_ids" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}
