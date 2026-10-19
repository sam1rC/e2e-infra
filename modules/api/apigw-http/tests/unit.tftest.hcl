mock_provider "aws" {
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      id            = "a1b2c3d4e5"
      api_endpoint  = "https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:a1b2c3d4e5"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/apigateway/acme-prod-api/access"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  project     = "acme"
  environment = "prod"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"

  integrations = {
    orders  = { lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:acme-prod-orders" }
    catalog = { lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:acme-prod-catalog", timeout_milliseconds = 5000 }
  }

  routes = {
    "GET /products"    = { integration = "catalog", authorization = "NONE" }
    "GET /orders"      = { integration = "orders" }
    "POST /orders"     = { integration = "orders", throttling_rate_limit = 10, throttling_burst_limit = 20 }
    "GET /orders/{id}" = { integration = "orders", scopes = ["orders/read"] }
  }

  jwt_authorizer = {
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_EXAMPLE1"
    audience = ["1example23456789"]
  }
}

run "http_api_behind_cloudfront" {
  command = plan

  assert {
    condition     = aws_apigatewayv2_api.this.protocol_type == "HTTP" && aws_apigatewayv2_api.this.name == "acme-prod-api" && aws_apigatewayv2_api.this.disable_execute_api_endpoint == false
    error_message = "HTTP API <project>-<env>-api con el endpoint execute-api activo (origen de CloudFront)."
  }

  assert {
    condition     = length(aws_apigatewayv2_api.this.cors_configuration) == 0
    error_message = "Sin cors no se configura CORS."
  }
}

run "lambda_proxy_integrations" {
  command = plan

  assert {
    condition = alltrue([
      for i in aws_apigatewayv2_integration.this :
      i.integration_type == "AWS_PROXY" && i.payload_format_version == "2.0" && i.integration_method == "POST"
    ])
    error_message = "Integraciones Lambda proxy con payload 2.0."
  }

  assert {
    condition = (
      aws_apigatewayv2_integration.this["catalog"].timeout_milliseconds == 5000 &&
      aws_apigatewayv2_integration.this["orders"].timeout_milliseconds == 29000 &&
      aws_apigatewayv2_integration.this["orders"].integration_uri == "arn:aws:lambda:us-east-1:123456789012:function:acme-prod-orders"
    )
    error_message = "Cada integración apunta a su función con su timeout (29 s por defecto)."
  }
}

run "routes_require_jwt_unless_public" {
  command = plan

  assert {
    condition = (
      aws_apigatewayv2_route.this["GET /orders"].authorization_type == "JWT" &&
      aws_apigatewayv2_route.this["POST /orders"].authorization_type == "JWT" &&
      aws_apigatewayv2_route.this["GET /products"].authorization_type == "NONE" &&
      aws_apigatewayv2_route.this["GET /products"].authorizer_id == null
    )
    error_message = "Las rutas usan el autorizador JWT salvo las declaradas públicas."
  }

  assert {
    condition = (
      toset(aws_apigatewayv2_route.this["GET /orders/{id}"].authorization_scopes) == toset(["orders/read"]) &&
      aws_apigatewayv2_route.this["GET /orders"].authorization_scopes == null
    )
    error_message = "Las scopes solo se exigen en las rutas que las declaran."
  }

  assert {
    condition = (
      aws_apigatewayv2_authorizer.jwt[0].authorizer_type == "JWT" &&
      toset(aws_apigatewayv2_authorizer.jwt[0].identity_sources) == toset(["$request.header.Authorization"]) &&
      aws_apigatewayv2_authorizer.jwt[0].jwt_configuration[0].issuer == "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_EXAMPLE1" &&
      toset(aws_apigatewayv2_authorizer.jwt[0].jwt_configuration[0].audience) == toset(["1example23456789"])
    )
    error_message = "El autorizador JWT valida emisor y audiencia del token de la cabecera Authorization."
  }
}

run "stage_logs_and_throttling" {
  command = plan

  assert {
    condition = (
      aws_apigatewayv2_stage.this.name == "$default" && aws_apigatewayv2_stage.this.auto_deploy &&
      aws_apigatewayv2_stage.this.default_route_settings[0].throttling_burst_limit == 100 &&
      aws_apigatewayv2_stage.this.default_route_settings[0].throttling_rate_limit == 50 &&
      aws_apigatewayv2_stage.this.default_route_settings[0].detailed_metrics_enabled
    )
    error_message = "Etapa $default con throttling por defecto y métricas detalladas."
  }

  assert {
    condition = (
      length(aws_apigatewayv2_stage.this.route_settings) == 1 &&
      alltrue([for s in aws_apigatewayv2_stage.this.route_settings : s.route_key == "POST /orders" && s.throttling_rate_limit == 10 && s.throttling_burst_limit == 20])
    )
    error_message = "Solo las rutas con límites propios tienen route_settings."
  }

  assert {
    condition = (
      jsondecode(aws_apigatewayv2_stage.this.access_log_settings[0].format).routeKey == "$context.routeKey" &&
      !strcontains(aws_apigatewayv2_stage.this.access_log_settings[0].format, "header") &&
      !strcontains(aws_apigatewayv2_stage.this.access_log_settings[0].format, "requestBody")
    )
    error_message = "Logs de acceso en JSON, sin cabeceras ni cuerpos."
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.access.name == "/aws/apigateway/acme-prod-api/access" &&
      aws_cloudwatch_log_group.access.kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555" &&
      aws_cloudwatch_log_group.access.retention_in_days == 90
    )
    error_message = "Log group de acceso cifrado con la CMK y con retención."
  }
}

run "lambda_permissions_scoped_to_this_api" {
  command = plan

  assert {
    condition = (
      toset(keys(aws_lambda_permission.this)) == toset(["orders", "catalog"]) &&
      alltrue([
        for p in aws_lambda_permission.this :
        p.principal == "apigateway.amazonaws.com" && p.source_account == "123456789012" && p.action == "lambda:InvokeFunction"
      ])
    )
    error_message = "Un permiso por función, solo para API Gateway de esta cuenta."
  }

  assert {
    condition = (
      aws_lambda_permission.this["orders"].statement_id == "AllowHttpApi-acme-prod-api-orders" &&
      aws_lambda_permission.this["orders"].source_arn == "arn:aws:execute-api:us-east-1:123456789012:a1b2c3d4e5/*/*"
    )
    error_message = "El permiso se limita al ARN de ejecución de esta API (statement_id por integración)."
  }
}

run "restricted_cors" {
  command = plan

  variables {
    cors = { allow_origins = ["https://shop.example.com"] }
  }

  assert {
    condition = (
      toset(aws_apigatewayv2_api.this.cors_configuration[0].allow_origins) == toset(["https://shop.example.com"]) &&
      aws_apigatewayv2_api.this.cors_configuration[0].allow_credentials == false &&
      aws_apigatewayv2_api.this.cors_configuration[0].max_age == 300
    )
    error_message = "CORS limitado al origen del frontend, sin credenciales por defecto."
  }
}

run "ssm_parameters" {
  command = plan

  assert {
    condition     = toset(keys(aws_ssm_parameter.this)) == toset(["api_id", "api_endpoint", "execution_arn"])
    error_message = "SSM publica ID, endpoint y ARN de ejecución."
  }
}

run "origin_domain_for_cloudfront" {
  command = apply

  assert {
    condition     = output.origin_domain_name == "a1b2c3d4e5.execute-api.us-east-1.amazonaws.com"
    error_message = "origin_domain_name es el dominio execute-api sin esquema."
  }
}

run "public_only_api_needs_no_authorizer" {
  command = plan

  variables {
    jwt_authorizer = null
    routes = {
      "GET /health" = { integration = "catalog", authorization = "NONE" }
    }
  }

  assert {
    condition     = length(aws_apigatewayv2_authorizer.jwt) == 0
    error_message = "Sin rutas JWT no hace falta autorizador."
  }
}

run "rejects_api_without_integrations" {
  command = plan

  variables {
    integrations = {}
  }

  expect_failures = [var.integrations]
}

run "rejects_api_without_routes" {
  command = plan

  variables {
    routes = {}
  }

  expect_failures = [var.routes]
}

run "rejects_invalid_route_key" {
  command = plan

  variables {
    routes = { "orders" = { integration = "orders" } }
  }

  expect_failures = [var.routes]
}

run "rejects_route_to_unknown_integration" {
  command = plan

  variables {
    routes = { "GET /users" = { integration = "users" } }
  }

  expect_failures = [var.routes]
}

run "rejects_jwt_routes_without_authorizer" {
  command = plan

  variables {
    jwt_authorizer = null
  }

  expect_failures = [var.routes]
}

run "rejects_scopes_on_public_routes" {
  command = plan

  variables {
    routes = { "GET /products" = { integration = "catalog", authorization = "NONE", scopes = ["openid"] } }
  }

  expect_failures = [var.routes]
}

run "rejects_wildcard_cors" {
  command = plan

  variables {
    cors = { allow_origins = ["*"] }
  }

  expect_failures = [var.cors]
}

run "rejects_localhost_cors_in_prod" {
  command = plan

  variables {
    cors = { allow_origins = ["http://localhost:3000"] }
  }

  expect_failures = [var.cors]
}

run "rejects_timeout_over_http_api_limit" {
  command = plan

  variables {
    integrations = {
      orders  = { lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:acme-prod-orders", timeout_milliseconds = 31000 }
      catalog = { lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:acme-prod-catalog" }
    }
  }

  expect_failures = [var.integrations]
}

run "rejects_non_https_issuer" {
  command = plan

  variables {
    jwt_authorizer = { issuer = "http://idp.example.com", audience = ["abc"] }
  }

  expect_failures = [var.jwt_authorizer]
}

run "rejects_short_log_retention_in_prod" {
  command = plan

  variables {
    log_retention_days = 30
  }

  expect_failures = [var.log_retention_days]
}
