output "budget_name" {
  description = "EN: Budget name / FR: Nom du budget"
  value       = aws_budgets_budget.monthly.name
}

output "monthly_limit" {
  description = "EN: Monthly limit / FR: Limite mensuelle"
  value       = "${aws_budgets_budget.monthly.limit_amount} ${aws_budgets_budget.monthly.limit_unit}"
}

output "sns_topic_arn" {
  description = "EN: SNS topic for alerts / FR: Sujet SNS des alertes"
  value       = aws_sns_topic.budget_alerts.arn
}

output "pending_confirmations" {
  description = "EN: Emails that must confirm the SNS subscription / FR: Courriels qui doivent confirmer l'abonnement SNS"
  value       = [for s in aws_sns_topic_subscription.email : s.endpoint if s.pending_confirmation]
}
