output "budget_id" {
  description = "EN: Budget resource ID / FR: ID de ressource du budget"
  value       = azurerm_consumption_budget_subscription.monthly.id
}

output "budget_start" {
  description = "EN: Budget start date / FR: Date de début du budget"
  value       = azurerm_consumption_budget_subscription.monthly.time_period[0].start_date
}

output "action_group_id" {
  description = "EN: Action group ID / FR: ID du groupe d'actions"
  value       = azurerm_monitor_action_group.budget.id
}
