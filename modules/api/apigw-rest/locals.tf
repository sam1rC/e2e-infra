locals {
  # Conocido al planificar aunque el ARN del Web ACL se calcule en el mismo apply.
  associate_web_acl = var.web_acl_enabled != null ? var.web_acl_enabled : var.web_acl_arn != null

  name       = "${var.project}-${var.environment}-${var.name}"
  ssm_prefix = "/${var.project}/${var.environment}/api/${var.name}"
  cors       = var.cors_allow_origin != null

  invoke_uri = "arn:${data.aws_partition.current.partition}:apigateway:${data.aws_region.current.region}:lambda:path/2015-03-31/functions/${var.lambda_function_arn}/invocations"

  # Proxy en la raíz y en /{proxy+}: la Lambda enruta por método y ruta.
  resource_ids = {
    root  = aws_api_gateway_rest_api.this.root_resource_id
    proxy = aws_api_gateway_resource.proxy.id
  }

  cors_headers = {
    "Access-Control-Allow-Origin"  = "'${coalesce(var.cors_allow_origin, "-")}'"
    "Access-Control-Allow-Headers" = "'authorization,content-type,x-api-key'"
    "Access-Control-Allow-Methods" = "'GET,POST,PUT,PATCH,DELETE,OPTIONS'"
    "Access-Control-Max-Age"       = "'300'"
  }

  # Sin cabeceras ni cuerpos (pueden llevar tokens, API keys o datos personales).
  access_log_format = jsonencode({
    requestId          = "$context.requestId"
    extendedRequestId  = "$context.extendedRequestId"
    requestTime        = "$context.requestTime"
    ip                 = "$context.identity.sourceIp"
    userAgent          = "$context.identity.userAgent"
    httpMethod         = "$context.httpMethod"
    resourcePath       = "$context.resourcePath"
    status             = "$context.status"
    protocol           = "$context.protocol"
    responseLength     = "$context.responseLength"
    responseLatency    = "$context.responseLatency"
    integrationLatency = "$context.integrationLatency"
    integrationStatus  = "$context.integration.status"
    integrationError   = "$context.integration.error"
    authorizerError    = "$context.authorizer.error"
    apiKeyId           = "$context.identity.apiKeyId"
    usagePlanId        = "$context.identity.usagePlanId"
    wafStatus          = "$context.waf.status"
    errorMessage       = "$context.error.message"
  })
}
