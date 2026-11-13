# EN: Layer 4: a warning-only check on something this module does not own: the RG's Owner tag.
# FR : Couche 4 : une vérification qui avertit seulement, sur un élément que ce module ne gère pas : l'étiquette Owner du RG.
check "resource_group_has_owner" {
  data "azurerm_resource_group" "this" {
    name = var.resource_group_name
  }

  assert {
    condition     = contains(keys(data.azurerm_resource_group.this.tags), "Owner")
    error_message = "EN: Resource group ${var.resource_group_name} has no Owner tag. / FR : Le groupe de ressources ${var.resource_group_name} n'a pas d'étiquette Owner."
  }
}
