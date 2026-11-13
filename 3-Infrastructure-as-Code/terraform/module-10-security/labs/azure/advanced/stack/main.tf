# =============================================================================
# Lab 10.A-AZ — A small stack to PLAN and GATE (you never need to apply it)
# Lab 10.A-AZ — Une petite pile à PLANIFIER et FILTRER (inutile de l'appliquer)
# =============================================================================

locals {
  tags = merge(
    {
      Course    = "terraform-cloud-engineer"
      Module    = "10-security"
      ManagedBy = "terraform"
    },
    var.owner == "" ? {} : { Owner = var.owner }
  )
}

resource "azurerm_resource_group" "this" {
  name     = "rg-tf-lab-m10-gate"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-tf-lab-m10-gate"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.100.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.100.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-tf-lab-m10-gate"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "https-from-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = var.ssh_from_internet ? [1] : []
    content {
      name                       = "ssh-from-internet-BAD"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_network_interface" "app" {
  name                = "nic-tf-lab-m10-gate"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-tf-lab-m10-gate"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id]
  tags                            = local.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
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
