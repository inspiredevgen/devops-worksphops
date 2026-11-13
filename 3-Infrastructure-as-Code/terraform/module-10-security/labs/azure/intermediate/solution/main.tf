# =============================================================================
# Lab 10.I-AZ — SOLUTION: every finding fixed, or accepted with a written justification
# Lab 10.I-AZ — SOLUTION : chaque constat corrigé, ou accepté avec une justification écrite
# =============================================================================

data "azurerm_client_config" "current" {}

locals {
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "10-security"
    ManagedBy = "terraform"
    Owner     = var.owner
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "app" {
  name     = "rg-tf-lab-m10-secure"
  location = var.location
  tags     = local.tags
}

# ------------------------------------------------------------ Network: private subnets, NSG everywhere
resource "azurerm_virtual_network" "app" {
  name                = "vnet-tf-lab-m10-secure"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = ["10.101.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  # EN: Scanner FALSE POSITIVE: both subnets get the NSG through the for_each association below.
  # FR : FAUX POSITIF du scanner : les deux sous-réseaux reçoivent le NSG via l'association for_each ci-dessous.
  #checkov:skip=CKV2_AZURE_31:False positive; NSG attached via azurerm_subnet_network_security_group_association.this (for_each).
  for_each = {
    app = "10.101.1.0/24"
    pe  = "10.101.2.0/24"
  }

  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = [each.value]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-tf-lab-m10-secure"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags

  # EN: No SSH at all: use Azure Bastion or `az vm run-command` for administration.
  # FR : Aucun SSH : utilisez Azure Bastion ou `az vm run-command` pour l'administration.
  security_rule {
    name                       = "https-from-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = azurerm_subnet.this

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# ------------------------------------------------------------ Storage: private, TLS 1.2, Entra ID only
#trivy:ignore:AZU-0057
#trivy:ignore:AZU-0058
#trivy:ignore:AZU-0060
resource "azurerm_storage_account" "data" {
  # EN: A BUSINESS trade-off, not a mistake: ZRS survives a zone failure and keeps data in one region
  #     (data residency). Geo-replication (GRS) would copy it to the paired region. Decide with the data owner.
  # FR : Un compromis MÉTIER, pas une erreur : ZRS survit à la panne d'une zone et garde les données dans une
  #     région (résidence des données). La géo-réplication (GRS) les copierait dans la région jumelée. À décider avec le propriétaire des données.
  #checkov:skip=CKV_AZURE_206:ZRS chosen for data residency; geo-replication is a data-owner decision.
  #checkov:skip=CKV2_AZURE_1:Platform-managed keys + infrastructure (double) encryption; CMK is a stretch goal.
  #checkov:skip=CKV_AZURE_33:No queues are used by this workload.
  #checkov:skip=CKV2_AZURE_21:Diagnostic logging to Log Analytics is added in the observability module.
  name                              = "sttflabm10${random_string.suffix.result}"
  resource_group_name               = azurerm_resource_group.app.name
  location                          = azurerm_resource_group.app.location
  account_tier                      = "Standard"
  account_replication_type          = "ZRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = false
  shared_access_key_enabled         = false
  infrastructure_encryption_enabled = true
  tags                              = local.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  sas_policy {
    expiration_period = "01.00:00:00" # EN: SAS tokens live 1 day max / FR : jetons SAS valides 1 jour maximum
  }
}

resource "azurerm_storage_container" "data" {
  #checkov:skip=CKV2_AZURE_21:Diagnostic logging to Log Analytics is added in the observability module.
  name                  = "data"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

# ------------------------------------------------------------ Key Vault: private, purge-protected
resource "azurerm_key_vault" "app" {
  name                          = "kvtfm10sec${random_string.suffix.result}"
  location                      = azurerm_resource_group.app.location
  resource_group_name           = azurerm_resource_group.app.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false
  tags                          = local.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# ------------------------------------------------------------ Private endpoints + DNS (Module 8)
locals {
  private_endpoints = {
    blob  = { resource_id = azurerm_storage_account.data.id, zone = "privatelink.blob.core.windows.net" }
    vault = { resource_id = azurerm_key_vault.app.id, zone = "privatelink.vaultcore.azure.net" }
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_endpoints

  name                = each.value.zone
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_endpoints

  name                  = "link-${each.key}"
  resource_group_name   = azurerm_resource_group.app.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.app.id
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "this" {
  for_each = local.private_endpoints

  name                = "pe-tf-lab-m10-${each.key}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  subnet_id           = azurerm_subnet.this["pe"].id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${each.key}"
    private_connection_resource_id = each.value.resource_id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.this[each.key].id]
  }
}

# ------------------------------------------------------------ Compute: private, key-only, approved size
# EN: Scanner FALSE POSITIVE: this NIC's subnet already has an NSG (subnet-level association).
# FR : FAUX POSITIF du scanner : le sous-réseau de cette NIC a déjà un NSG (association au niveau du sous-réseau).
#trivy:ignore:AZU-0068
resource "azurerm_network_interface" "app" {
  name                = "nic-tf-lab-m10-secure"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.this["app"].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-tf-lab-m10-secure"
  location                        = azurerm_resource_group.app.location
  resource_group_name             = azurerm_resource_group.app.name
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  allow_extension_operations      = false
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
