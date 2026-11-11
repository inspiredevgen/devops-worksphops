# EN: SPLAT [*] → a list of one attribute from every instance.
# FR: SPLAT [*] → la liste d'un attribut de chaque instance.
output "numbered_groups" {
  description = "EN: Numbered group names / FR: Noms des groupes numérotés"
  value       = azurerm_resource_group.numbered[*].name
}

output "named_groups" {
  description = "EN: { short name => group } / FR: { nom court => groupe }"
  value       = zipmap(var.group_names, azurerm_resource_group.named[*].name)
}

# EN: one() → the element or null; [0] would FAIL when count = 0.
# FR: one() → l'élément ou null ; [0] ÉCHOUERAIT quand count = 0.
output "audit_group" {
  description = "EN: Audit group or null / FR: Groupe d'audit ou null"
  value       = one(azurerm_resource_group.audit[*].name)
}
