# Threat protection (PLUS): bloquea credenciales filtradas y pide MFA según el riesgo del inicio de sesión.
resource "aws_cognito_risk_configuration" "this" {
  count = local.plus ? 1 : 0

  user_pool_id = aws_cognito_user_pool.this.id

  compromised_credentials_risk_configuration {
    event_filter = ["SIGN_IN", "SIGN_UP", "PASSWORD_CHANGE"]

    actions {
      event_action = var.threat_protection.compromised_credentials_action
    }
  }

  account_takeover_risk_configuration {
    actions {
      low_action {
        event_action = var.threat_protection.low_action
        notify       = false
      }

      medium_action {
        event_action = var.threat_protection.medium_action
        notify       = local.notify_on_risk
      }

      high_action {
        event_action = var.threat_protection.high_action
        notify       = local.notify_on_risk
      }
    }

    dynamic "notify_configuration" {
      for_each = local.notify_on_risk ? [var.threat_protection.notify] : []

      content {
        source_arn = notify_configuration.value.source_arn
        from       = notify_configuration.value.from
        reply_to   = notify_configuration.value.reply_to
      }
    }
  }
}
