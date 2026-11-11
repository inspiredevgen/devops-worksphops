# -----------------------------------------------------------------------------
# Lab 0.A-AWS — Cost guardrails as code: AWS Budget + SNS alerts
# Lab 0.A-AWS — Garde-fous de coûts en code : AWS Budget + alertes SNS
#
# EN: A monthly cost budget with three alerts (actual 50%, actual 80%,
#     forecasted 100%) sent by email AND to an SNS topic (which you can later
#     wire to Slack, Teams or a Lambda that stops resources).
#     Cost: AWS Budgets for monitoring is free or near-free at this scale;
#     SNS email notifications fall within the free tier.
# FR: Un budget mensuel avec trois alertes (réel 50 %, réel 80 %, prévision
#     100 %) envoyées par courriel ET vers un sujet SNS (que vous pourrez relier
#     plus tard à Slack, Teams ou une Lambda qui arrête des ressources).
#     Coût : AWS Budgets est gratuit ou presque à cette échelle ;
#     les notifications SNS par courriel restent dans l'offre gratuite.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# EN: SNS topic + policy so the AWS Budgets service can publish to it.
# FR: Sujet SNS + politique pour que le service AWS Budgets puisse y publier.
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "budget_alerts" {
  name = "tf-lab-budget-alerts"
}

data "aws_iam_policy_document" "sns_budgets" {
  statement {
    sid       = "AllowBudgetsToPublish"
    effect    = "Allow"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.budget_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    # EN: Confused-deputy protection: only budgets from THIS account.
    # FR: Protection « confused deputy » : uniquement les budgets de CE compte.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn    = aws_sns_topic.budget_alerts.arn
  policy = data.aws_iam_policy_document.sns_budgets.json
}

# EN: One email subscription per address. `for_each` is a preview of Module 5.
#     Each recipient must click "Confirm subscription" in the email AWS sends.
# FR: Un abonnement courriel par adresse. `for_each` est un aperçu du module 5.
#     Chaque destinataire doit cliquer « Confirm subscription » dans le courriel.
resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# -----------------------------------------------------------------------------
# EN: The budget itself.
# FR: Le budget lui-même.
# -----------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = format("%.2f", var.monthly_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # EN: Alert 1 — warning on ACTUAL spend.
  # FR: Alerte 1 — avertissement sur les dépenses RÉELLES.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.actual_thresholds_pct.warning
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
  }

  # EN: Alert 2 — critical on ACTUAL spend.
  # FR: Alerte 2 — critique sur les dépenses RÉELLES.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.actual_thresholds_pct.critical
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
  }

  # EN: Alert 3 — FORECAST says you will exceed 100% this month.
  # FR: Alerte 3 — la PRÉVISION indique un dépassement de 100 % ce mois-ci.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
  }

  # EN: The topic policy must exist before Budgets tries to publish.
  # FR: La politique du sujet doit exister avant que Budgets tente de publier.
  depends_on = [aws_sns_topic_policy.budget_alerts]
}
