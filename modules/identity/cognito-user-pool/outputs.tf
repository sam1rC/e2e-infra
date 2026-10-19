output "user_pool_id" {
  description = "ID del user pool."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN del user pool (provider_arns del autorizador COGNITO_USER_POOLS de REST API)."
  value       = aws_cognito_user_pool.this.arn
}

output "issuer_url" {
  description = "Emisor de los JWT (iss): issuer del JWT authorizer de HTTP API y de la validación en la aplicación."
  value       = "https://${aws_cognito_user_pool.this.endpoint}"
}

output "jwks_uri" {
  description = "URL de las claves públicas para validar la firma de los JWT."
  value       = "https://${aws_cognito_user_pool.this.endpoint}/.well-known/jwks.json"
}

output "client_ids" {
  description = "ID de cada app client por clave (audience del JWT authorizer)."
  value       = { for k, c in aws_cognito_user_pool_client.this : k => c.id }
}

output "tenant_id_claim" {
  description = "Claim con el tenant del usuario en el ID token (custom:tenant_id); null si el pool no tiene el atributo. En el access token solo aparece si lo añade el trigger pre token generation."
  value       = local.tenant_id_claim
}

output "domain_url" {
  description = "URL base de managed login (authorize, token, logout); null sin dominio."
  value = !local.managed_login ? null : (
    local.custom_domain ? "https://${var.domain.custom_domain}" : "https://${var.domain.prefix}.auth.${data.aws_region.current.region}.amazoncognito.com"
  )
}

output "custom_domain_alias" {
  description = "Destino del registro alias de Route 53 para el dominio propio (distribución de CloudFront de Cognito); null sin dominio propio."
  value = local.custom_domain ? {
    name    = aws_cognito_user_pool_domain.this[0].cloudfront_distribution
    zone_id = aws_cognito_user_pool_domain.this[0].cloudfront_distribution_zone_id
  } : null
}

output "log_group_names" {
  description = "Log group de Cognito: auth_events (actividad con evaluación de riesgo) en PLUS o notifications (errores de envío) en el resto."
  value = merge(
    local.plus ? {} : { notifications = aws_cloudwatch_log_group.notifications[0].name },
    local.plus ? { auth_events = aws_cloudwatch_log_group.auth_events[0].name } : {},
  )
}
