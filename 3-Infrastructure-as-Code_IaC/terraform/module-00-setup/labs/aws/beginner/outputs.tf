# EN: Outputs print useful values after `terraform apply` / `terraform output`.
# FR: Les sorties affichent des valeurs utiles après `terraform apply` / `terraform output`.

output "account_id" {
  description = "EN: AWS account ID / FR: ID du compte AWS"
  value       = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  description = "EN: Identity Terraform is using / FR: Identité utilisée par Terraform"
  value       = data.aws_caller_identity.current.arn
}

output "region" {
  description = "EN: Configured region / FR: Région configurée"
  value       = data.aws_region.current.region
}

output "availability_zones" {
  description = "EN: AZs in this region / FR: Zones de disponibilité de la région"
  value       = data.aws_availability_zones.available.names
}
