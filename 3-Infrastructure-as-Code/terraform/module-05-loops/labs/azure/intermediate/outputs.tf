output "subnet_cidrs" {
  description = "EN: { subnet => CIDR } / FR: { sous-réseau => CIDR }"
  value       = { for k, s in azurerm_subnet.this : k => s.address_prefixes[0] }
}

output "subnets_with_nsg" {
  description = "EN: Subnets protected by an NSG / FR: Sous-réseaux protégés par un NSG"
  value       = sort(keys(azurerm_subnet_network_security_group_association.this))
}

# EN: GROUPING with `...` → { analytics = [..], platform = [..], support = [..] }
# FR: REGROUPEMENT avec `...` → { analytics = [..], platform = [..], support = [..] }
output "identity_client_ids_by_team" {
  description = "EN: Identity client IDs grouped by team / FR: ID clients des identités groupés par équipe"
  value       = { for te in local.team_envs : te.team => azurerm_user_assigned_identity.team[te.key].client_id... }
}

output "identity_keys" {
  description = "EN: The flattened keys used by for_each / FR: Les clés aplaties utilisées par for_each"
  value       = sort(keys(azurerm_user_assigned_identity.team))
}
