output "url" {
  description = "EN: Public URL / FR: URL publique"
  value       = "http://${azurerm_public_ip.lb.fqdn}"
}

output "fqdn" {
  description = "EN: For Traffic Manager endpoints / FR: Pour les points de terminaison Traffic Manager"
  value       = azurerm_public_ip.lb.fqdn
}

output "public_ip" {
  description = "EN: For Route 53 records / FR: Pour les enregistrements Route 53"
  value       = azurerm_public_ip.lb.ip_address
}

output "vmss_name" {
  value = azurerm_linux_virtual_machine_scale_set.app.name
}

output "resource_group_name" {
  value = local.rg_name
}

output "rendered_cloud_init" {
  description = "EN: For tests / FR: Pour les tests"
  value       = local.cloud_init
}

output "render_command" {
  description = "EN: For tests / FR: Pour les tests"
  value       = local.render_command
}
