# -----------------------------------------------------------------------------
# EN: IMPORT BLOCKS — reviewable in a PR, shown in `terraform plan` before
#     anything is written to state. Delete this file after the import (step 3).
# FR: BLOCS IMPORT — révisables en PR, affichés dans `terraform plan` avant
#     toute écriture dans l'état. Supprimez ce fichier après l'import (étape 3).
# -----------------------------------------------------------------------------

import {
  to = azurerm_resource_group.legacy
  id = var.legacy_rg_id
}

import {
  to = azurerm_storage_account.legacy
  id = var.legacy_storage_id
}

# EN: No resource block for this address → run
#       terraform plan -generate-config-out=generated_nsg.tf
# FR: Aucun bloc de ressource pour cette adresse → exécutez
#       terraform plan -generate-config-out=generated_nsg.tf
import {
  to = azurerm_network_security_group.legacy
  id = var.legacy_nsg_id
}
