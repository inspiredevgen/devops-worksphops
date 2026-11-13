output "url" {
  value = "http://${azurerm_public_ip.this.ip_address}"
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

# EN: custom_data is sensitive in the provider, so tests inspect the rendered document here.
# FR : custom_data est sensible dans le provider, donc les tests inspectent ici le document rendu.
output "rendered_cloud_init" {
  value = local.cloud_init
}
