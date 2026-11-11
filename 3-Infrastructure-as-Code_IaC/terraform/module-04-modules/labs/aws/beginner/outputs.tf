output "vpc_id" {
  description = "EN: VPC ID (from the module) / FR: ID du VPC (depuis le module)"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "EN: Public subnets / FR: Sous-réseaux publics"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "EN: Private subnets / FR: Sous-réseaux privés"
  value       = module.vpc.private_subnets
}

output "web_security_group_id" {
  description = "EN: SG created in the ROOT module / FR: SG créé dans le module RACINE"
  value       = aws_security_group.web.id
}
