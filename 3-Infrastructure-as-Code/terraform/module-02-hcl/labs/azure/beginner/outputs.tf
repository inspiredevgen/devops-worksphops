output "vm_id" {
  description = "EN: VM resource ID / FR: ID de ressource de la VM"
  value       = azurerm_linux_virtual_machine.web.id
}

output "vm_name" {
  description = "EN: VM name / FR: Nom de la VM"
  value       = azurerm_linux_virtual_machine.web.name
}

output "resource_group_name" {
  description = "EN: Resource group / FR: Groupe de ressources"
  value       = azurerm_resource_group.lab.name
}

output "private_ip" {
  description = "EN: Private IP / FR: IP privée"
  value       = azurerm_linux_virtual_machine.web.private_ip_address
}

output "image_used" {
  description = "EN: Image version selected by the data source / FR: Version d'image choisie par la source de données"
  value       = "${data.azurerm_platform_image.ubuntu.offer}/${data.azurerm_platform_image.ubuntu.sku}:${data.azurerm_platform_image.ubuntu.version}"
}
