# -----------------------------------------------------------------------------
# Lab 3.A-AZ — Brownfield adoption: import, refactor, release
# Lab 3.A-AZ — Adoption de l'existant : importer, restructurer, libérer
#
# EN: STARTER FILE. These blocks describe resources that ALREADY EXIST
#     (created by scripts/setup.sh). The NSG has NO block on purpose:
#     Terraform will GENERATE it (step 2).
# FR: FICHIER DE DÉPART. Ces blocs décrivent des ressources qui EXISTENT DÉJÀ
#     (créées par scripts/setup.sh). Le NSG n'a volontairement AUCUN bloc :
#     Terraform va le GÉNÉRER (étape 2).
# -----------------------------------------------------------------------------

locals {
  # EN: Existing tags + the course tags Terraform will add after import.
  # FR: Étiquettes existantes + celles du cours que Terraform ajoutera après l'import.
  tags = {
    owner     = "clickops"
    app       = "legacy"
    course    = "terraform-cloud-engineer"
    module    = "03-state"
    managedBy = "terraform"
  }
}

# EN: Step 4 renames this address to azurerm_resource_group.app with `moved`.
# FR: L'étape 4 renomme cette adresse en azurerm_resource_group.app avec `moved`.
resource "azurerm_resource_group" "legacy" {
  name     = "rg-tf-lab-m03-legacy"
  location = var.location
  tags     = local.tags
}

# EN: Hand-written to match what the CLI created. After import, run
#     `terraform plan` and reconcile any differences until only the tag
#     update remains.
# FR: Écrit à la main pour correspondre à ce que la CLI a créé. Après l'import,
#     lancez `terraform plan` et réconciliez les différences jusqu'à ce qu'il ne
#     reste que la mise à jour des étiquettes.
resource "azurerm_storage_account" "legacy" {
  name                = var.legacy_storage_account_name
  resource_group_name = azurerm_resource_group.legacy.name
  location            = azurerm_resource_group.legacy.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = local.tags
}
