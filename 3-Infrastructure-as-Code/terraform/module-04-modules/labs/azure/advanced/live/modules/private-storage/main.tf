# -----------------------------------------------------------------------------
# EN: A small, opinionated module: a private, TLS-only storage account that
#     can be locked down to specific subnets (+ admin IPs).
# FR: Un petit module opiniâtre : un compte de stockage privé, TLS uniquement,
#     qui peut être limité à des sous-réseaux précis (+ IP admin).
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "this" {
  name                = "${var.name_prefix}${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  network_rules {
    # EN: length() of a list is known at plan time even if the IDs are not.
    # FR: length() d'une liste est connu au plan même si les ID ne le sont pas.
    default_action             = length(var.allowed_subnet_ids) > 0 ? "Deny" : "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.admin_ip_rules
  }

  tags = var.tags
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
