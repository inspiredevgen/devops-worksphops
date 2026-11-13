# =============================================================================
# Lab 9.I-AZ — Unit tests for secure-storage with a MOCKED provider
# Lab 9.I-AZ — Tests unitaires de secure-storage avec un provider SIMULÉ
# Run from this folder / Lancer depuis ce dossier :  terraform init && terraform test
# =============================================================================

mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      tags = { Owner = "platform-team" }
    }
  }

  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-unit/providers/Microsoft.Storage/storageAccounts/stunittest"
    }
  }
}

mock_provider "azurerm" {
  alias = "untagged_rg"

  mock_data "azurerm_resource_group" {
    defaults = {
      tags = {}
    }
  }
}

variables {
  name                = "stunittest"
  resource_group_name = "rg-unit"
  location            = "canadacentral"
  environment         = "dev"
}

# ------------------------------------------------------------ Secure defaults
run "defaults_are_secure" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.min_tls_version == "TLS1_2"
    error_message = "TLS 1.2 minimum."
  }

  assert {
    condition     = azurerm_storage_account.this.https_traffic_only_enabled
    error_message = "HTTPS only."
  }

  assert {
    condition     = azurerm_storage_account.this.allow_nested_items_to_be_public == false
    error_message = "No public blobs or containers."
  }

  assert {
    condition     = azurerm_storage_account.this.blob_properties[0].versioning_enabled
    error_message = "Blob versioning must be on."
  }

  assert {
    condition     = azurerm_storage_account.this.blob_properties[0].delete_retention_policy[0].days == 7
    error_message = "Soft delete must default to 7 days."
  }

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "LRS"
    error_message = "dev defaults to LRS (cheapest)."
  }
}

# ------------------------------------------------------------ Guardrails fire
run "rejects_invalid_name" {
  command = plan

  variables {
    name = "St-Invalid"
  }

  expect_failures = [var.name]
}

run "rejects_unknown_replication" {
  command = plan

  variables {
    replication_type = "XRS"
  }

  expect_failures = [var.replication_type]
}

run "prod_rejects_lrs" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [azurerm_storage_account.this]
}

run "prod_accepts_zrs" {
  command = plan

  variables {
    environment      = "prod"
    replication_type = "ZRS"
  }

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "ZRS"
    error_message = "ZRS must be accepted in prod."
  }
}

run "warns_when_rg_has_no_owner" {
  command = plan

  providers = {
    azurerm = azurerm.untagged_rg
  }

  expect_failures = [check.resource_group_has_owner]
}

# ------------------------------------------------------------ Apply with mocks
run "outputs_after_apply" {
  command = apply

  assert {
    condition     = endswith(output.id, "/storageAccounts/stunittest")
    error_message = "id must come from the storage account."
  }
}
