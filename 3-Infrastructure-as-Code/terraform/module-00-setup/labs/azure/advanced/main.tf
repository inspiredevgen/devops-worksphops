# -----------------------------------------------------------------------------
# Lab 0.A-AZ — Cost guardrails as code: subscription budget + action group
# Lab 0.A-AZ — Garde-fous de coûts en code : budget d'abonnement + groupe d'actions
#
# EN: A monthly subscription budget with three alerts (actual 50%, actual 80%,
#     forecasted 100%) sent by email AND to an Azure Monitor action group
#     (which you can later extend with SMS, webhooks, Logic Apps…).
#     Cost: budgets are free; action-group email notifications are free at
#     this volume.
# FR: Un budget d'abonnement mensuel avec trois alertes (réel 50 %, réel 80 %,
#     prévision 100 %) envoyées par courriel ET à un groupe d'actions Azure
#     Monitor (extensible plus tard : SMS, webhooks, Logic Apps…).
#     Coût : les budgets sont gratuits ; les courriels du groupe d'actions
#     sont gratuits à ce volume.
# -----------------------------------------------------------------------------

data "azurerm_subscription" "current" {}

locals {
  # EN: Azure requires the budget to start on the 1st of a month (UTC).
  #     timestamp() changes on every run, so we ignore later changes below.
  # FR: Azure exige que le budget commence le 1er d'un mois (UTC).
  #     timestamp() change à chaque exécution : nous ignorons donc ces changements.
  budget_start = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())

  tags = {
    course    = "terraform-cloud-engineer"
    module    = "00-setup"
    managedBy = "terraform"
  }
}

# EN: Action groups live in a resource group.
# FR: Les groupes d'actions résident dans un groupe de ressources.
resource "azurerm_resource_group" "cost" {
  name     = "rg-tf-lab-cost"
  location = var.location
  tags     = local.tags
}

resource "azurerm_monitor_action_group" "budget" {
  name                = "ag-tf-lab-budget"
  resource_group_name = azurerm_resource_group.cost.name
  short_name          = "tflabbudget" # EN: max 12 chars / FR: 12 caractères max
  tags                = local.tags

  # EN: One email_receiver per address. `dynamic` is a preview of Module 5.
  # FR: Un email_receiver par adresse. `dynamic` est un aperçu du module 5.
  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = var.budget_name
  subscription_id = data.azurerm_subscription.current.id # EN/FR: "/subscriptions/<id>"
  amount          = var.monthly_limit
  time_grain      = "Monthly"

  time_period {
    start_date = local.budget_start
  }

  # EN: Alert 1 — warning on ACTUAL spend.
  # FR: Alerte 1 — avertissement sur les dépenses RÉELLES.
  notification {
    enabled        = true
    threshold      = var.actual_thresholds_pct.warning
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.alert_emails
    contact_groups = [azurerm_monitor_action_group.budget.id]
  }

  # EN: Alert 2 — critical on ACTUAL spend.
  # FR: Alerte 2 — critique sur les dépenses RÉELLES.
  notification {
    enabled        = true
    threshold      = var.actual_thresholds_pct.critical
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.alert_emails
    contact_groups = [azurerm_monitor_action_group.budget.id]
  }

  # EN: Alert 3 — FORECAST says you will exceed 100% this month.
  # FR: Alerte 3 — la PRÉVISION indique un dépassement de 100 % ce mois-ci.
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.alert_emails
    contact_groups = [azurerm_monitor_action_group.budget.id]
  }

  # EN: Without this, every plan would try to change start_date (timestamp()
  #     is re-evaluated each run). Preview of `lifecycle` — Module 1.
  # FR: Sans cela, chaque plan tenterait de modifier start_date (timestamp()
  #     est réévalué à chaque exécution). Aperçu de `lifecycle` — module 1.
  lifecycle {
    ignore_changes = [time_period]
  }
}
