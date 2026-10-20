# Log groups creados antes de la entrega, con la CMK y retención. Bajo /aws/vendedlogs/ la entrega de logs de
# AWS no depende del tamaño de la resource policy de CloudWatch Logs de la cuenta.
# Errores de envío de correo/SMS: en los pools que no son PLUS (ver la limitación de la entrega más abajo).
resource "aws_cloudwatch_log_group" "notifications" {
  count = local.plus ? 0 : 1

  name              = "${local.log_group_root}/notifications"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Actividad de usuarios con evaluación de riesgo (IP, dispositivo, credenciales comprometidas): solo en PLUS.
resource "aws_cloudwatch_log_group" "auth_events" {
  count = local.plus ? 1 : 0

  name              = "${local.log_group_root}/auth-events"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Una sola configuración de entrega por pool: con dos (userNotification + userAuthEvents) AWS las devuelve en
# un orden no determinista y el provider (lista ordenada, recurso "best effort") falla con "inconsistent
# result after apply" (comprobado en la sandbox el 2026-10-14, provider 6.68.0). En PLUS se registra la
# actividad con evaluación de riesgo (la razón de pagar PLUS); en el resto, los errores de envío.
resource "aws_cognito_log_delivery_configuration" "this" {
  user_pool_id = aws_cognito_user_pool.this.id

  log_configurations {
    event_source = local.plus ? "userAuthEvents" : "userNotification"
    log_level    = local.plus ? "INFO" : "ERROR"

    cloud_watch_logs_configuration {
      log_group_arn = local.plus ? aws_cloudwatch_log_group.auth_events[0].arn : aws_cloudwatch_log_group.notifications[0].arn
    }
  }

  # Los eventos de actividad solo existen con la threat protection activa.
  depends_on = [aws_cognito_risk_configuration.this]
}

# El log group de notificaciones pasó a ser condicional: los pools ya desplegados (no PLUS) conservan el suyo.
moved {
  from = aws_cloudwatch_log_group.notifications
  to   = aws_cloudwatch_log_group.notifications[0]
}
