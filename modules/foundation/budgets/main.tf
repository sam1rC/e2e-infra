resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  time_unit    = "MONTHLY"
  limit_amount = tostring(var.monthly_limit_usd)
  limit_unit   = "USD"

  dynamic "notification" {
    for_each = toset(var.alert_thresholds_percent)

    content {
      comparison_operator        = "GREATER_THAN"
      notification_type          = "ACTUAL"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = var.alert_emails
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = var.alert_emails
  }

  tags = var.tags
}

# Solo un monitor DIMENSIONAL/SERVICE por cuenta, y AWS ya crea uno por defecto en las cuentas nuevas.
resource "aws_ce_anomaly_monitor" "services" {
  count = var.existing_anomaly_monitor_arn == null ? 1 : 0

  name              = "${local.name}-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = var.tags
}

resource "aws_ce_anomaly_subscription" "this" {
  name             = "${local.name}-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [local.anomaly_monitor_arn]

  dynamic "subscriber" {
    for_each = toset(var.alert_emails)

    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }

  tags = var.tags
}

moved {
  from = aws_ce_anomaly_monitor.services
  to   = aws_ce_anomaly_monitor.services[0]
}
