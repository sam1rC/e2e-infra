resource "aws_apigatewayv2_api" "this" {
  name          = local.name
  description   = "HTTP API de ${var.project}/${var.environment} (detras de CloudFront)"
  protocol_type = "HTTP"

  disable_execute_api_endpoint = var.disable_execute_api_endpoint

  dynamic "cors_configuration" {
    for_each = var.cors == null ? [] : [var.cors]

    content {
      allow_origins     = cors_configuration.value.allow_origins
      allow_methods     = cors_configuration.value.allow_methods
      allow_headers     = cors_configuration.value.allow_headers
      expose_headers    = cors_configuration.value.expose_headers
      max_age           = cors_configuration.value.max_age_seconds
      allow_credentials = cors_configuration.value.allow_credentials
    }
  }

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.jwt_authorizer == null ? 0 : 1

  api_id           = aws_apigatewayv2_api.this.id
  name             = "${local.name}-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = var.jwt_authorizer.issuer
    audience = var.jwt_authorizer.audience
  }
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = var.integrations

  api_id                 = aws_apigatewayv2_api.this.id
  description            = each.key
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = each.value.lambda_function_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = each.value.timeout_milliseconds
}

resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  #checkov:skip=CKV_AWS_309:JWT por defecto; NONE solo en rutas declaradas públicas a propósito (catálogo, salud).
  api_id               = aws_apigatewayv2_api.this.id
  route_key            = each.key
  target               = "integrations/${aws_apigatewayv2_integration.this[each.value.integration].id}"
  authorization_type   = each.value.authorization
  authorizer_id        = each.value.authorization == "JWT" ? aws_apigatewayv2_authorizer.jwt[0].id : null
  authorization_scopes = length(each.value.scopes) > 0 ? each.value.scopes : null
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${local.name}/access"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format          = local.access_log_format
  }

  default_route_settings {
    throttling_burst_limit   = var.throttling.burst_limit
    throttling_rate_limit    = var.throttling.rate_limit
    detailed_metrics_enabled = true
  }

  dynamic "route_settings" {
    for_each = local.route_throttling

    content {
      route_key                = route_settings.key
      throttling_burst_limit   = coalesce(route_settings.value.throttling_burst_limit, var.throttling.burst_limit)
      throttling_rate_limit    = coalesce(route_settings.value.throttling_rate_limit, var.throttling.rate_limit)
      detailed_metrics_enabled = true
    }
  }

  tags = var.tags

  # Las route_settings se refieren a rutas que deben existir antes.
  depends_on = [aws_apigatewayv2_route.this]
}

# Solo esta API (cualquier etapa y ruta) puede invocar cada función, y solo desde esta cuenta.
resource "aws_lambda_permission" "this" {
  for_each = var.integrations

  statement_id   = "AllowHttpApi-${local.name}-${each.key}"
  action         = "lambda:InvokeFunction"
  function_name  = each.value.lambda_function_arn
  principal      = "apigateway.amazonaws.com"
  source_arn     = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
  source_account = data.aws_caller_identity.current.account_id
}
