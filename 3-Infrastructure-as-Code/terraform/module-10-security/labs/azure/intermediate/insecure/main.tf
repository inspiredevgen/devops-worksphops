# =============================================================================
# Lab 10.I-AZ — INSECURE ON PURPOSE. Scan it, never apply it.
# Lab 10.I-AZ — NON SÉCURISÉ EXPRÈS. Scannez-le, ne l'appliquez jamais.
# =============================================================================

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# EN: Fake IDs and secret, but the PATTERN (a client secret in code) is the problem.
# FR : Des ID et un secret factices, mais le MODÈLE (un secret client dans le code) est le problème.
provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
  tenant_id       = "11111111-1111-1111-1111-111111111111"
  client_id       = "22222222-2222-2222-2222-222222222222"
  client_secret   = "Q~fake.client.secret.do.not.use~1234567890"
}

resource "azurerm_resource_group" "app" {
  name     = "rg-tf-lab-m10-insecure"
  location = "canadacentral"
}

resource "azurerm_storage_account" "data" {
  name                            = "sttflabm10insecure"
  resource_group_name             = azurerm_resource_group.app.name
  location                        = azurerm_resource_group.app.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = false
  min_tls_version                 = "TLS1_0"
  allow_nested_items_to_be_public = true
}

resource "azurerm_storage_container" "public" {
  name                  = "public"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "blob"
}

resource "azurerm_virtual_network" "app" {
  name                = "vnet-tf-lab-m10-insecure"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = ["10.100.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.100.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-tf-lab-m10-insecure"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  security_rule {
    name                       = "ssh-from-anywhere"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "app" {
  name                = "pip-tf-lab-m10-insecure"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "app" {
  name                = "nic-tf-lab-m10-insecure"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-tf-lab-m10-insecure"
  location                        = azurerm_resource_group.app.location
  resource_group_name             = azurerm_resource_group.app.name
  size                            = "Standard_D8s_v5"
  admin_username                  = "azureuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.app.id]

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

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "app" {
  name                     = "kv-tf-lab-m10-insecure"
  location                 = azurerm_resource_group.app.location
  resource_group_name      = azurerm_resource_group.app.name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = false
}
