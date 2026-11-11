output "generated_rules" {
  description = "EN: Rule name → priority, as computed / FR: Nom de règle → priorité, telle que calculée"
  value       = { for r in local.nsg_rules : "${r.tier}-${r.name}" => r.priority }
}

output "asg_ids" {
  description = "EN: { tier => ASG ID } / FR: { niveau => ID de l'ASG }"
  value       = { for k, a in azurerm_application_security_group.tier : k => a.id }
}

output "storage_account_name" {
  description = "EN: Storage account with generated lifecycle rules / FR: Compte de stockage avec règles de cycle de vie générées"
  value       = azurerm_storage_account.data.name
}
