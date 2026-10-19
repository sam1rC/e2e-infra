# Preflight de CORS: el navegador no envía el token en OPTIONS, así que estos métodos no llevan autorizador
# ni API key y responden con un MOCK (no invocan la Lambda ni exponen datos).
resource "aws_api_gateway_method" "options" {
  for_each = local.cors ? local.resource_ids : {}

  #checkov:skip=CKV_AWS_59:Preflight de CORS: el navegador no envía credenciales en OPTIONS; respuesta MOCK sin datos.
  #checkov:skip=CKV2_AWS_53:Preflight MOCK sin cuerpo ni parámetros que validar.
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = each.value
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "options" {
  for_each = local.cors ? local.resource_ids : {}

  rest_api_id       = aws_api_gateway_rest_api.this.id
  resource_id       = each.value
  http_method       = aws_api_gateway_method.options[each.key].http_method
  type              = "MOCK"
  request_templates = { "application/json" = jsonencode({ statusCode = 200 }) }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = local.cors ? local.resource_ids : {}

  rest_api_id         = aws_api_gateway_rest_api.this.id
  resource_id         = each.value
  http_method         = aws_api_gateway_method.options[each.key].http_method
  status_code         = "200"
  response_parameters = { for h in keys(local.cors_headers) : "method.response.header.${h}" => true }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = local.cors ? local.resource_ids : {}

  rest_api_id         = aws_api_gateway_rest_api.this.id
  resource_id         = each.value
  http_method         = aws_api_gateway_method.options[each.key].http_method
  status_code         = aws_api_gateway_method_response.options[each.key].status_code
  response_parameters = { for h, v in local.cors_headers : "method.response.header.${h}" => v }

  depends_on = [aws_api_gateway_integration.options]
}

# Las respuestas de error de API Gateway (401 del autorizador, 403 de WAF o de API key, 429, 5xx) no pasan
# por la Lambda: sin estas cabeceras el navegador oculta el error real tras un fallo de CORS.
resource "aws_api_gateway_gateway_response" "cors" {
  for_each = local.cors ? toset(["DEFAULT_4XX", "DEFAULT_5XX"]) : toset([])

  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = each.key
  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "gatewayresponse.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
  }
}
