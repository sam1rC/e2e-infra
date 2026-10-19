resource "aws_api_gateway_rest_api" "this" {
  name        = local.name
  description = "REST API de ${var.project}/${var.environment} (detras de CloudFront)"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # TLS 1.3/1.2 en el endpoint execute-api y SNI/Host estrictos (cierra el domain fronting).
  security_policy      = var.security_policy
  endpoint_access_mode = var.endpoint_access_mode

  api_key_source           = "HEADER"
  minimum_compression_size = var.minimum_compression_size == null ? null : tostring(var.minimum_compression_size)

  tags = merge(var.tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_authorizer" "cognito" {
  rest_api_id     = aws_api_gateway_rest_api.this.id
  name            = "${local.name}-cognito"
  type            = "COGNITO_USER_POOLS"
  provider_arns   = var.cognito_user_pool_arns
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_method" "any" {
  for_each = local.resource_ids

  #checkov:skip=CKV2_AWS_53:Integración proxy: la Lambda valida cuerpo y parámetros con sus propios esquemas (dependen de cada cliente).
  rest_api_id          = aws_api_gateway_rest_api.this.id
  resource_id          = each.value
  http_method          = "ANY"
  authorization        = "COGNITO_USER_POOLS"
  authorizer_id        = aws_api_gateway_authorizer.cognito.id
  authorization_scopes = length(var.authorization_scopes) > 0 ? var.authorization_scopes : null
  api_key_required     = var.api_key_required
  request_parameters   = each.key == "proxy" ? { "method.request.path.proxy" = true } : null
}

resource "aws_api_gateway_integration" "any" {
  for_each = local.resource_ids

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = each.value
  http_method             = aws_api_gateway_method.any[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = local.invoke_uri
  timeout_milliseconds    = var.integration_timeout_milliseconds
}

# Solo esta etapa de esta API puede invocar la función, y solo desde esta cuenta.
resource "aws_lambda_permission" "this" {
  statement_id   = "AllowRestApi-${local.name}"
  action         = "lambda:InvokeFunction"
  function_name  = var.lambda_function_arn
  principal      = "apigateway.amazonaws.com"
  source_arn     = "${aws_api_gateway_rest_api.this.execution_arn}/${var.stage_name}/*/*"
  source_account = data.aws_caller_identity.current.account_id
}
