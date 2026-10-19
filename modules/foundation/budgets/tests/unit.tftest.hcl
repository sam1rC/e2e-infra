mock_provider "aws" {
  mock_resource "aws_ce_anomaly_monitor" {
    defaults = {
      arn = "arn:aws:ce::123456789012:anomalymonitor/11111111-2222-3333-4444-555555555555"
    }
  }
}

variables {
  project           = "acme"
  environment       = "dev"
  monthly_limit_usd = 200
  alert_emails      = ["team@example.com"]
}

run "default_thresholds_are_80_100_120_actual_plus_100_forecast" {
  command = plan

  assert {
    condition = toset([
      for n in aws_budgets_budget.monthly.notification : "${n.notification_type}-${n.threshold}"
      ]) == toset([
      "ACTUAL-80", "ACTUAL-100", "ACTUAL-120", "FORECASTED-100",
    ])
    error_message = "Deben existir alertas reales al 80/100/120% y una prevista al 100%."
  }
}

run "budget_amount_and_name" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly.name == "acme-dev-monthly" && aws_budgets_budget.monthly.limit_amount == "200" && aws_budgets_budget.monthly.limit_unit == "USD"
    error_message = "Nombre, importe y unidad del presupuesto incorrectos."
  }
}

run "anomaly_monitor_is_dimensional_by_service" {
  command = plan

  assert {
    condition     = aws_ce_anomaly_monitor.services[0].monitor_type == "DIMENSIONAL" && aws_ce_anomaly_monitor.services[0].monitor_dimension == "SERVICE"
    error_message = "El monitor debe ser dimensional por servicio."
  }
}

run "existing_monitor_is_reused_not_duplicated" {
  command = plan

  variables {
    existing_anomaly_monitor_arn = "arn:aws:ce::123456789012:anomalymonitor/c341a423-6360-40b3-bc57-e4fe7c62f8e6"
  }

  assert {
    condition     = length(aws_ce_anomaly_monitor.services) == 0
    error_message = "Con un monitor existente no se crea otro (AWS solo admite uno por servicio)."
  }

  assert {
    condition     = toset(aws_ce_anomaly_subscription.this.monitor_arn_list) == toset(["arn:aws:ce::123456789012:anomalymonitor/c341a423-6360-40b3-bc57-e4fe7c62f8e6"]) && output.anomaly_monitor_arn == "arn:aws:ce::123456789012:anomalymonitor/c341a423-6360-40b3-bc57-e4fe7c62f8e6"
    error_message = "La suscripción y la salida deben usar el monitor existente."
  }
}

run "rejects_malformed_monitor_arn" {
  command = plan

  variables {
    existing_anomaly_monitor_arn = "Default-Services-Monitor"
  }

  expect_failures = [var.existing_anomaly_monitor_arn]
}

run "anomaly_subscription_has_one_subscriber_per_email" {
  command = plan

  variables {
    alert_emails = ["a@example.com", "b@example.com"]
  }

  assert {
    condition     = length(aws_ce_anomaly_subscription.this.subscriber) == 2
    error_message = "Debe haber un suscriptor por correo."
  }
}

run "rejects_empty_emails" {
  command = plan

  variables {
    alert_emails = []
  }

  expect_failures = [var.alert_emails]
}

run "rejects_invalid_email" {
  command = plan

  variables {
    alert_emails = ["not-an-email"]
  }

  expect_failures = [var.alert_emails]
}

run "rejects_non_positive_limit" {
  command = plan

  variables {
    monthly_limit_usd = 0
  }

  expect_failures = [var.monthly_limit_usd]
}
