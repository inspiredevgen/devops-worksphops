output "hosts" {
  description = "EN: Name → public IP (ssh) or local tunnel port (bastion) / FR: Nom → IP publique (ssh) ou port de tunnel local (bastion)"
  value       = { for n in local.names : n => local.ssh ? azurerm_public_ip.host[n].ip_address : "127.0.0.1:${local.port[n]}" }
}

output "inventory_path" {
  value = var.inventory_path == null ? null : local_file.inventory[0].filename
}

output "lb_address" {
  description = "EN: load_balancer: the public IP of the load balancer / FR : load_balancer : l'IP publique de l'équilibreur"
  value       = local.lb ? azurerm_public_ip.lb[0].ip_address : null
}

# EN: Module 7: a STRUCTURED handoff to Ansible (read with cloud.terraform.terraform_output, then add_host).
# FR : Module 7 : un passage de relais STRUCTURÉ vers Ansible (lu avec cloud.terraform.terraform_output, puis add_host).
output "ansible_hosts" {
  description = "EN: name → connection data and groups / FR : nom → données de connexion et groupes"
  value = {
    for n in local.names : n => {
      address     = local.ssh ? azurerm_public_ip.host[n].ip_address : "127.0.0.1"
      port        = local.ssh ? 22 : local.port[n]
      user        = "azureuser"
      role        = var.hosts[n].role
      environment = var.hosts[n].environment
      os          = var.hosts[n].os
      vm_name     = azurerm_linux_virtual_machine.host[n].name
    }
  }
}

output "scale_set_name" {
  value = local.vmss ? azurerm_linux_virtual_machine_scale_set.web[0].name : null
}
