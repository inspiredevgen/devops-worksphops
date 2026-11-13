output "url" {
  description = "EN: The ONE address users need / FR : La SEULE adresse dont les utilisateurs ont besoin"
  value       = "http://${azurerm_traffic_manager_profile.this.fqdn}"
}

output "endpoint_status_command" {
  value = "az network traffic-manager endpoint list -g ${azurerm_resource_group.global.name} --profile-name ${azurerm_traffic_manager_profile.this.name} --query \"[].{name:name, priority:priority, status:endpointMonitorStatus}\" -o table"
}
