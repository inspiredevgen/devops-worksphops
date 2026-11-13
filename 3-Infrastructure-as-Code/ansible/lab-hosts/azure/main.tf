# =============================================================================
# Azure VM lab hosts: one VNet, an NSG, Ubuntu and AlmaLinux VMs, tags that Ansible will use.
# Hôtes de lab VM Azure : un VNet, un NSG, des VM Ubuntu et AlmaLinux, des étiquettes utilisées par Ansible.
# =============================================================================

locals {
  ssh   = var.access == "ssh"
  names = sort(keys(var.hosts))
  tags = {
    Course    = "ansible-cloud-engineer"
    Module    = var.module_tag
    ManagedBy = "terraform"
  }

  # EN: AlmaLinux comes from its free COMMUNITY GALLERY image: the Marketplace version needs a EULA per subscription.
  # FR : AlmaLinux vient de son image gratuite de GALERIE COMMUNAUTAIRE : la version Marketplace exige un CLUF par abonnement.
  almalinux_image_id = "/CommunityGalleries/almalinux-56b45196-f8a2-4e53-858a-bc4d0ebca440/Images/almalinux-9-gen2/Versions/latest"
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-ans-lab-hosts"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-ans-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.140.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "hosts" {
  name                 = "snet-hosts"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.140.1.0/24"]
}

resource "azurerm_network_security_group" "hosts" {
  name                = "nsg-ans-lab-hosts"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  # EN: ssh mode: port 22 from YOUR IP. bastion mode: from the Bastion subnet only.
  # FR : mode ssh : port 22 depuis VOTRE IP. mode bastion : depuis le sous-réseau Bastion seulement.
  security_rule {
    name                       = "ssh-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.ssh ? "${coalesce(var.my_ip, "127.0.0.1")}/32" : "10.140.0.0/26"
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = local.ssh ? var.open_ports : []
    content {
      name                       = "lab-${security_rule.value}-in"
      priority                   = 110 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value)
      source_address_prefix      = "${coalesce(var.my_ip, "127.0.0.1")}/32"
      destination_address_prefix = "*"
    }
  }

  lifecycle {
    precondition {
      condition     = !local.ssh || var.my_ip != null
      error_message = "EN: ssh mode needs my_ip. / FR : le mode ssh exige my_ip."
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "hosts" {
  subnet_id                 = azurerm_subnet.hosts.id
  network_security_group_id = azurerm_network_security_group.hosts.id
}

resource "azurerm_public_ip" "host" {
  for_each = local.ssh ? var.hosts : {}

  name                = "pip-ans-lab-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "host" {
  for_each = var.hosts

  name                = "nic-ans-lab-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.hosts.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = local.ssh ? azurerm_public_ip.host[each.key].id : null
  }
}

resource "azurerm_linux_virtual_machine" "host" {
  for_each = var.hosts

  name                            = "vm-ans-lab-${each.key}"
  computer_name                   = each.key
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  size                            = var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.host[each.key].id]
  source_image_id                 = each.value.os == "almalinux" ? local.almalinux_image_id : null

  tags = merge(local.tags, each.value.tags, {
    Host        = each.key # EN: the inventory hostname for dynamic inventory (Module 4) / FR : le nom d'hôte d'inventaire
    Role        = each.value.role
    Environment = each.value.environment
    OS          = each.value.os
  })

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  dynamic "source_image_reference" {
    for_each = each.value.os == "ubuntu" ? [1] : []
    content {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      version   = "latest"
    }
  }

  depends_on = [azurerm_subnet_network_security_group_association.hosts]
}
