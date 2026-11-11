# EN: MAP comprehension: { key => value } over a resource that uses for_each.
# FR: Compréhension de MAP : { clé => valeur } sur une ressource utilisant for_each.
output "subnet_cidrs" {
  description = "EN: { subnet => CIDR } / FR: { sous-réseau => CIDR }"
  value       = { for k, s in aws_subnet.this : k => s.cidr_block }
}

# EN: GROUPING with `...`: several values under the same key become a list.
#     → { app = [id, id], db = [id, id], web = [id, id] }
# FR: REGROUPEMENT avec `...` : plusieurs valeurs sous la même clé forment une liste.
#     → { app = [id, id], db = [id, id], web = [id, id] }
output "subnet_ids_by_tier" {
  description = "EN: Subnet IDs grouped by tier / FR: ID des sous-réseaux groupés par niveau"
  value       = { for k, s in aws_subnet.this : split("-", k)[0] => s.id... }
}

# EN: LIST comprehension with a filter.
# FR: Compréhension de LISTE avec un filtre.
output "public_subnet_ids" {
  description = "EN: Public subnet IDs / FR: ID des sous-réseaux publics"
  value       = [for k, s in aws_subnet.this : s.id if var.subnets[k].public]
}

output "team_role_arns" {
  description = "EN: { team => role ARN } / FR: { équipe => ARN du rôle }"
  value       = { for k, r in aws_iam_role.team : k => r.arn }
}

output "policy_attachments" {
  description = "EN: The flattened keys used by for_each / FR: Les clés aplaties utilisées par for_each"
  value       = sort(keys(aws_iam_role_policy_attachment.team))
}
