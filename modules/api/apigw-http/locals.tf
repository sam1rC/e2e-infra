locals {
  name       = "${var.project}-${var.environment}-${var.name}"
  ssm_prefix = "/${var.project}/${var.environment}/api/${var.name}"

  # Formato JSON de los logs de acceso: sin cabeceras ni cuerpos (pueden llevar tokens o datos personales).
  access_log_format = jsonencode({
    requestId          = "$context.requestId"
    extendedRequestId  = "$context.extendedRequestId"
    requestTime        = "$context.requestTime"
    ip                 = "$context.identity.sourceIp"
    userAgent          = "$context.identity.userAgent"
    httpMethod         = "$context.httpMethod"
    routeKey           = "$context.routeKey"
    path               = "$context.path"
    status             = "$context.status"
    protocol           = "$context.protocol"
    responseLength     = "$context.responseLength"
    responseLatency    = "$context.responseLatency"
    integrationLatency = "$context.integrationLatency"
    integrationStatus  = "$context.integrationStatus"
    integrationError   = "$context.integrationErrorMessage"
    authorizerError    = "$context.authorizer.error"
    principalId        = "$context.authorizer.principalId"
    errorMessage       = "$context.error.message"
  })

  route_throttling = {
    for k, r in var.routes : k => r if r.throttling_burst_limit != null || r.throttling_rate_limit != null
  }
}
