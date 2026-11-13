# EN: Outputs are the module's RETURN VALUES — the only way callers can
#     reach anything inside. Expose IDs, not whole resource objects.
# FR: Les sorties sont les VALEURS DE RETOUR du module — le seul moyen pour
#     l'appelant d'accéder à son contenu. Exposez des ID, pas des objets entiers.

output "vpc_id" {
  description = "EN: VPC ID / FR: ID du VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "EN: VPC CIDR / FR: CIDR du VPC"
  value       = aws_vpc.main.cidr_block
}

output "azs" {
  description = "EN: AZs used / FR: Zones utilisées"
  value       = local.azs
}

output "public_subnet_ids" {
  description = "EN: Public subnet IDs, ordered by AZ / FR: ID des sous-réseaux publics, triés par zone"
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "EN: Private subnet IDs, ordered by AZ / FR: ID des sous-réseaux privés, triés par zone"
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "public_route_table_id" {
  description = "EN: Public route table ID / FR: ID de la table de routage publique"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "EN: Private route table ID / FR: ID de la table de routage privée"
  value       = aws_route_table.private.id
}

# EN: v1.1.0 — null when the endpoint is disabled.
# FR: v1.1.0 — null quand le point de terminaison est désactivé.
output "s3_endpoint_id" {
  description = "EN: S3 gateway endpoint ID or null / FR: ID du point de terminaison S3 ou null"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}
