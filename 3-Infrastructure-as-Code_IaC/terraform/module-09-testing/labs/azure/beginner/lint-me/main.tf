# =============================================================================
# EN: LINT-ME: valid Terraform with SEVERAL problems. `terraform validate` passes; tflint does not.
#     NEVER apply this folder. Fix it until `tflint --chdir=lint-me` is clean.
# FR : LINT-ME : du Terraform valide avec PLUSIEURS problèmes. `terraform validate` passe ; tflint, non.
#     N'appliquez JAMAIS ce dossier. Corrigez-le jusqu'à ce que `tflint --chdir=lint-me` soit propre.
# =============================================================================

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "vmName" {
  default = "web"
}

variable "unused_disk_size" {
  type    = number
  default = 64
}

resource "azurerm_linux_virtual_machine" "Web" {
  name                  = var.vmName
  resource_group_name   = "rg-lint-me"
  location              = "canadacentral"
  size                  = "Standard_B1x"
  admin_username        = "azureuser"
  network_interface_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lint-me/providers/Microsoft.Network/networkInterfaces/nic-web"]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ== lint-me"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
