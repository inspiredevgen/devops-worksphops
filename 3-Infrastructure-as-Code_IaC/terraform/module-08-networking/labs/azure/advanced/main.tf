# =============================================================================
# Lab 8.A-AZ — Hub-and-spoke, private endpoint + private DNS, optional firewall
# Lab 8.A-AZ — Hub-and-spoke, point de terminaison privé + DNS privé, pare-feu facultatif
#
#        app spoke ◄──peering──► HUB (firewall?) ◄──peering──► data spoke
#                                                              └─ storage via private endpoint
#   EN: Peering is NOT transitive: app ↔ data needs routes through a firewall/NVA in the hub.
#   FR : L'appairage n'est PAS transitif : app ↔ data exige des routes via un pare-feu/NVA dans le hub.
# =============================================================================

locals {
  name = "tf-lab-m08-hub"
  tags = {
    Course    = "terraform-cloud-engineer"
    Module    = "08-networking"
    ManagedBy = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# ------------------------------------------------------------------------ Hub
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.hub_cidr]
  tags                = local.tags
}

# EN: Azure Firewall REQUIRES these exact subnet names, /26 or larger.
# FR : Azure Firewall EXIGE ces noms de sous-réseaux exacts, en /26 ou plus grand.
resource "azurerm_subnet" "hub" {
  for_each = {
    AzureFirewallSubnet           = cidrsubnet(var.hub_cidr, 10, 0) # 10.95.0.0/26
    AzureFirewallManagementSubnet = cidrsubnet(var.hub_cidr, 10, 1) # 10.95.0.64/26
    snet-shared                   = cidrsubnet(var.hub_cidr, 8, 1)  # 10.95.1.0/24
  }

  name                 = each.key
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [each.value]
}

# --------------------------------------------------------------------- Spokes
resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "vnet-tf-lab-m08-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [each.value]
  tags                = local.tags
}

locals {
  spoke_subnets = merge([
    for spoke, cidr in var.spokes : {
      "${spoke}/workload" = { spoke = spoke, name = "snet-workload", cidr = cidrsubnet(cidr, 8, 1) }
      "${spoke}/pe"       = { spoke = spoke, name = "snet-private-endpoints", cidr = cidrsubnet(cidr, 8, 2) }
    }
  ]...)
}

resource "azurerm_subnet" "spoke" {
  for_each = local.spoke_subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.spoke[each.value.spoke].name
  address_prefixes     = [each.value.cidr]
}

# ------------------------------------------------- Peerings: hub ↔ every spoke
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke[each.key].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.this.name
  virtual_network_name         = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  # EN: Accept traffic the hub firewall forwards from OTHER spokes.
  # FR : Accepter le trafic que le pare-feu du hub transfère depuis les AUTRES rayons.
  allow_forwarded_traffic = true
}

# ------------------------------------- Storage reachable ONLY via private endpoint
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "data" {
  name                          = "sttflabm08${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false # EN: the whole point / FR : tout l'intérêt
  tags                          = local.tags
}

# EN: The zone name is FIXED by Azure for blob private endpoints.
# FR : Le nom de la zone est FIXÉ par Azure pour les points de terminaison privés blob.
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

# EN: Link the zone to every VNet that must resolve the private IP.
# FR : Lier la zone à chaque VNet qui doit résoudre l'IP privée.
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  for_each = merge(
    { hub = azurerm_virtual_network.hub.id },
    { for k, v in azurerm_virtual_network.spoke : k => v.id }
  )

  name                  = "link-${each.key}"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = each.value
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pe-${azurerm_storage_account.data.name}-blob"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.spoke["data/pe"].id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.data.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  # EN: Azure writes the A record into the private zone for us.
  # FR : Azure écrit pour nous l'enregistrement A dans la zone privée.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# -------------------------------------------------------------------- Outputs
output "storage_account" {
  value = azurerm_storage_account.data.name
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.blob.private_service_connection[0].private_ip_address
}

output "verify_commands" {
  value = {
    peerings    = "az network vnet peering list -g ${azurerm_resource_group.this.name} --vnet-name ${azurerm_virtual_network.hub.name} --query '[].{name:name,state:peeringState}' -o table"
    dns_record  = "az network private-dns record-set a list -g ${azurerm_resource_group.this.name} -z privatelink.blob.core.windows.net --query '[].{name:name,ip:aRecords[0].ipv4Address}' -o table"
    public_dns  = "nslookup ${azurerm_storage_account.data.name}.blob.core.windows.net"
    public_deny = "curl -s -o /dev/null -w '%%{http_code}\\n' 'https://${azurerm_storage_account.data.name}.blob.core.windows.net/?comp=list'"
  }
}
