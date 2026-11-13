# -----------------------------------------------------------------------------
# Lab 2.B-AZ — A Linux VM driven by variables, data sources and outputs
# Lab 2.B-AZ — Une VM Linux pilotée par des variables, sources de données et sorties
#
# EN: No public IP: the VM is private (more secure, cheaper). You'll check it
#     with `az vm run-command`. Cost: Standard_B1s ≈ 1 cent/hour + a small
#     disk charge. DESTROY at the end of the lab.
# FR: Pas d'IP publique : la VM est privée (plus sûr, moins cher). Vous la
#     vérifierez avec `az vm run-command`. Coût : Standard_B1s ≈ 1 cent/heure
#     + un petit coût de disque. DÉTRUISEZ en fin de lab.
# -----------------------------------------------------------------------------

# EN: DATA SOURCE — find the latest Ubuntu 24.04 image version in this region.
# FR: SOURCE DE DONNÉES — trouver la dernière version de l'image Ubuntu 24.04 dans la région.
data "azurerm_platform_image" "ubuntu" {
  location  = var.location
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
  sku       = "server"
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = {
    course      = "terraform-cloud-engineer"
    module      = "02-hcl"
    environment = var.environment
  }
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "vms" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-${var.project_name}-${var.environment}"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]

  # EN: file() reads a local file; pathexpand() turns "~" into your home folder.
  # FR: file() lit un fichier local ; pathexpand() transforme « ~ » en dossier personnel.
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = data.azurerm_platform_image.ubuntu.publisher
    offer     = data.azurerm_platform_image.ubuntu.offer
    sku       = data.azurerm_platform_image.ubuntu.sku
    version   = data.azurerm_platform_image.ubuntu.version
  }

  tags = azurerm_resource_group.lab.tags
}
