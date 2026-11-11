# =============================================================================
# secure-storage: a storage account with four layers of guardrails
# secure-storage : un compte de stockage avec quatre couches de garde-fous
#   1. variable validation (variables.tf) · 2. precondition · 3. postcondition · 4. check (checks.tf)
# =============================================================================

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.replication_type

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.delete_retention_days
    }
  }

  tags = { Environment = var.environment }

  lifecycle {
    # EN: Layer 2: production data must survive a zone or region failure.
    # FR : Couche 2 : les données de production doivent survivre à la panne d'une zone ou d'une région.
    precondition {
      condition     = var.environment != "prod" || var.replication_type != "LRS"
      error_message = "EN: prod needs zone or geo redundancy (not LRS). / FR : la prod exige une redondance de zone ou géographique (pas LRS)."
    }

    # EN: Layer 3: the result must match what we promise our users.
    # FR : Couche 3 : le résultat doit correspondre à ce que nous promettons.
    postcondition {
      condition     = self.min_tls_version == "TLS1_2" && self.https_traffic_only_enabled && !self.allow_nested_items_to_be_public
      error_message = "EN: TLS 1.2, HTTPS-only and no public blobs are mandatory. / FR : TLS 1.2, HTTPS seulement et aucun blob public sont obligatoires."
    }
  }
}
