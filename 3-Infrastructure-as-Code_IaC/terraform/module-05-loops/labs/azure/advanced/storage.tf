# -----------------------------------------------------------------------------
# Lab 5.A-AZ (part 2) — Repeated rules + an optional nested block
# Lab 5.A-AZ (partie 2) — Règles répétées + un bloc imbriqué optionnel
#
# EN: Cost: $0 (empty storage account; lifecycle policies are free).
# FR: Coût : 0 $ (compte de stockage vide ; stratégies de cycle de vie gratuites).
# -----------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "data" {
  name                = "sttfm05dyn${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location

  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true # EN: required for version actions / FR: requis pour les actions sur versions
  }

  tags = local.tags
}

resource "azurerm_storage_management_policy" "data" {
  storage_account_id = azurerm_storage_account.data.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    iterator = lc

    content {
      name    = lc.value.name
      enabled = true

      filters {
        prefix_match = [lc.value.prefix]
        blob_types   = ["blockBlob"]
      }

      actions {
        # EN: Optional block: only when at least one base-blob action is set.
        #     Null attributes inside `content` are simply omitted.
        # FR: Bloc optionnel : seulement si au moins une action base_blob est définie.
        #     Les attributs null dans `content` sont simplement omis.
        dynamic "base_blob" {
          for_each = anytrue([
            for v in [lc.value.cool_after_days, lc.value.archive_after_days, lc.value.delete_after_days] : v != null
          ]) ? [lc.value] : []

          content {
            tier_to_cool_after_days_since_modification_greater_than    = base_blob.value.cool_after_days
            tier_to_archive_after_days_since_modification_greater_than = base_blob.value.archive_after_days
            delete_after_days_since_modification_greater_than          = base_blob.value.delete_after_days
          }
        }

        # EN: Optional block idiom: [] = absent, [value] = present.
        # FR: Idiome de bloc optionnel : [] = absent, [valeur] = présent.
        dynamic "version" {
          for_each = lc.value.delete_versions_after_days == null ? [] : [lc.value.delete_versions_after_days]

          content {
            delete_after_days_since_creation = version.value
          }
        }
      }
    }
  }
}
