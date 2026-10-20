resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  description = "Despliegue de ${local.name}"

  # Nuevo despliegue cuando cambia la definición de la API. Solo entradas de configuración: hashear los
  # recursos completos incluía atributos que AWS rellena tras crearlos y redesplegaba en cada plan
  # (detectado en la sandbox el 2026-10-14).
  triggers = {
    redeployment = sha1(jsonencode({
      proxy_resource = aws_api_gateway_resource.proxy.id
      authorizer     = { id = aws_api_gateway_authorizer.cognito.id, user_pools = var.cognito_user_pool_arns }
      methods        = { scopes = var.authorization_scopes, api_key_required = var.api_key_required }
      integration    = { uri = local.invoke_uri, timeout = var.integration_timeout_milliseconds }
      cors           = local.cors ? local.cors_headers : null
      compression    = var.minimum_compression_size
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${local.name}/access"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# API Gateway crearía este log group sin cifrado ni caducidad: se crea antes con la CMK y retención.
resource "aws_cloudwatch_log_group" "execution" {
  count = var.logging_level == "OFF" ? 0 : 1

  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.this.id}/${var.stage_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_api_gateway_stage" "this" {
  #checkov:skip=CKV_AWS_120:Sin caché: las respuestas dependen del tenant y del token (una caché compartida podría servir datos de otro tenant).
  #checkov:skip=CKV2_AWS_51:Sin certificado de cliente: el origen se protege con la cabecera de CloudFront y el WAF regional (ADR 0010).
  #checkov:skip=CKV_AWS_73:X-Ray desactivado por defecto (variable): OpenTelemetry de extremo a extremo; activar ambos duplica trazas (ADR 0008).
  #checkov:skip=CKV2_AWS_77:El Web ACL lo crea edge/waf-web-acl (otro módulo) con KnownBadInputsRuleSet, que incluye las reglas de Log4j.
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name

  xray_tracing_enabled = var.xray_tracing_enabled

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format          = local.access_log_format
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.execution, aws_api_gateway_account.this]
}

resource "aws_api_gateway_method_settings" "all" {
  #checkov:skip=CKV_AWS_225:Sin caché: las respuestas dependen del tenant y del token (una caché compartida podría servir datos de otro tenant).
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = var.logging_level
    data_trace_enabled     = false
    caching_enabled        = false
    throttling_burst_limit = var.throttling.burst_limit
    throttling_rate_limit  = var.throttling.rate_limit
  }
}

resource "aws_api_gateway_usage_plan" "this" {
  for_each = var.usage_plans

  name        = "${local.name}-${each.key}"
  description = each.value.description

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  throttle_settings {
    rate_limit  = each.value.rate_limit
    burst_limit = each.value.burst_limit
  }

  dynamic "quota_settings" {
    for_each = each.value.quota_limit == null ? [] : [1]

    content {
      limit  = each.value.quota_limit
      period = each.value.quota_period
    }
  }

  tags = merge(var.tags, { Tier = each.key })
}

resource "aws_wafv2_web_acl_association" "this" {
  count = local.associate_web_acl ? 1 : 0

  resource_arn = aws_api_gateway_stage.this.arn
  web_acl_arn  = var.web_acl_arn
}
