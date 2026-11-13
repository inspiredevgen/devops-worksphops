# =============================================================================
# scale_set != null: a VM Scale Set of Ubuntu web servers (Module 7, day-2 operations).
#   Terraform IGNORES later capacity changes (instances): Ansible scales it. Each instance gets a public IP (ssh mode).
# scale_set != null : un VM Scale Set de serveurs web Ubuntu (module 7, opérations de jour 2).
# =============================================================================
locals {
  vmss = var.scale_set != null
}

resource "azurerm_linux_virtual_machine_scale_set" "web" {
  count = local.vmss ? 1 : 0

  name                            = "vmss-ans-lab-web"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  sku                             = var.vm_size
  instances                       = var.scale_set.capacity
  admin_username                  = "azureuser"
  disable_password_authentication = true
  upgrade_mode                    = "Manual"
  computer_name_prefix            = "vmssweb"

  tags = merge(local.tags, {
    Role        = "web"
    Environment = "dev"
    OS          = "ubuntu"
  })

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name      = "primary"
      primary   = true
      subnet_id = azurerm_subnet.hosts.id

      public_ip_address {
        name = "pip"
      }
    }
  }

  lifecycle {
    ignore_changes = [instances]
    precondition {
      condition     = local.ssh && var.my_ip != null
      error_message = "EN: scale_set needs access = \"ssh\" and my_ip. / FR : scale_set exige access = « ssh » et my_ip."
    }
  }

  depends_on = [azurerm_subnet_network_security_group_association.hosts]
}
