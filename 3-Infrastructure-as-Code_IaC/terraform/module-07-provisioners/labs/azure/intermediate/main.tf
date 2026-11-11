# -----------------------------------------------------------------------------
# Lab 7.I-AZ — The web server again, now with safe local hooks (see hooks.tf)
# Lab 7.I-AZ — Le serveur web, avec des crochets locaux sûrs (voir hooks.tf)
#
# EN: No provisioner, no SSH session: the VM configures ITSELF at first boot.
#     Cost: Standard_B1s + a Standard public IP ≈ 2 cents/hour. DESTROY after.
# FR: Ni provisioner, ni session SSH : la VM se configure ELLE-MÊME au premier
#     démarrage. Coût : Standard_B1s + IP publique Standard ≈ 2 cents/heure. DÉTRUISEZ ensuite.
# -----------------------------------------------------------------------------

locals {
  tags = {
    course = "terraform-cloud-engineer"
    module = "07-provisioners"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-tf-lab-m07-web"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-tf-lab-m07"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.87.0.0/16"]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.87.1.0/24"]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-tf-lab-m07-web"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  security_rule {
    name                       = "http-from-my-ip"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "${var.my_ip}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_public_ip" "web" {
  name                = "pip-tf-lab-m07-web"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "web" {
  name                = "nic-tf-lab-m07-web"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-tf-lab-m07-web"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  # EN: custom_data must be BASE64. Changing it FORCES a new VM (it only
  #     runs at first boot) — the immutable approach.
  # FR: custom_data doit être en BASE64. Le modifier FORCE une nouvelle VM
  #     (il ne s'exécute qu'au premier démarrage) — l'approche immuable.
  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    title   = "tf-lab-m07"
    message = var.page_message
  }))

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

  tags = local.tags

  depends_on = [azurerm_subnet_network_security_group_association.web]
}

output "url" {
  description = "EN: Web server URL (allow ~2-3 min for boot) / FR: URL du serveur web (prévoir ~2-3 min de démarrage)"
  value       = "http://${azurerm_public_ip.web.ip_address}"
}

output "vm_name" {
  description = "EN: VM name / FR: Nom de la VM"
  value       = azurerm_linux_virtual_machine.web.name
}
