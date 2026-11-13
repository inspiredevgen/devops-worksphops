# =============================================================================
# web-server (Azure): the Module 7 web server as a module with unit AND integration tests
# web-server (Azure) : le serveur web du module 7 en module avec tests unitaires ET d'intégration
# =============================================================================

locals {
  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    title   = var.name
    message = var.message
  })
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "09-testing"
    ManagedBy = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-tf-lab-m09-${var.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.99.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.99.1.0/24"]
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "allow-http-from-allowed-cidr"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "this" {
  # EN: An ACCEPTED risk, documented where it lives. / FR : Un risque ACCEPTÉ, documenté là où il se trouve.
  #checkov:skip=CKV_AZURE_119:Public web server by design for this lab; port 80 is limited to allowed_cidr.
  name                = "nic-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                            = "vm-${var.name}"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.this.id]
  custom_data                     = base64encode(local.cloud_init)
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

  # EN: Wait for the NSG to be attached, or the first HTTP checks could hit an unprotected subnet.
  # FR : Attendre l'association du NSG, sinon les premiers tests HTTP pourraient viser un sous-réseau non protégé.
  depends_on = [azurerm_subnet_network_security_group_association.this]
}
