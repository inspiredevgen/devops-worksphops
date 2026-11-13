# -----------------------------------------------------------------------------
# Lab 5.B-AZ — count: N copies, lists, and conditional resources
# Lab 5.B-AZ — count : N copies, listes et ressources conditionnelles
#
# EN: Empty resource groups → $0.
# FR: Groupes de ressources vides → 0 $.
# -----------------------------------------------------------------------------

locals {
  tags = {
    course = "terraform-cloud-engineer"
    module = "05-loops"
  }
}

# EN: 1) count = a NUMBER → N copies. count.index = 0, 1, 2…
# FR: 1) count = un NOMBRE → N copies. count.index = 0, 1, 2…
resource "azurerm_resource_group" "numbered" {
  count = var.group_count

  name     = "rg-tf-lab-m05-n${count.index}"
  location = var.location
  tags     = local.tags
}

# EN: 2) count over a LIST → identified by POSITION.
#        ⚠️ Removing "logs" shifts every index → the others get REPLACED.
# FR: 2) count sur une LISTE → identifiés par leur POSITION.
#        ⚠️ Retirer « logs » décale chaque index → les autres sont REMPLACÉS.
resource "azurerm_resource_group" "named" {
  count = length(var.group_names)

  name     = "rg-tf-lab-m05-${var.group_names[count.index]}"
  location = var.location
  tags     = local.tags
}

# EN: 3) CONDITIONAL resource: count = condition ? 1 : 0
# FR: 3) Ressource CONDITIONNELLE : count = condition ? 1 : 0
resource "azurerm_resource_group" "audit" {
  count = var.create_audit_group ? 1 : 0

  name     = "rg-tf-lab-m05-audit"
  location = var.location
  tags     = local.tags
}
