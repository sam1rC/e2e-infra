mock_provider "aws" {
  mock_resource "aws_api_gateway_rest_api" {
    defaults = {
      id               = "a1b2c3d4e5"
      root_resource_id = "rootid0001"
      execution_arn    = "arn:aws:execute-api:us-east-1:123456789012:a1b2c3d4e5"
    }
  }

  mock_resource "aws_api_gateway_resource" {
    defaults = {
      id = "proxyid001"
    }
  }

  mock_resource "aws_api_gateway_stage" {
    defaults = {
      arn        = "arn:aws:apigateway:us-east-1::/restapis/a1b2c3d4e5/stages/v1"
      invoke_url = "https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com/v1"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/apigateway/acme-prod-api/access"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/acme-prod-apigw-cloudwatch"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  project                = "acme"
  environment            = "prod"
  kms_key_arn            = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  lambda_function_arn    = "arn:aws:lambda:us-east-1:123456789012:function:acme-prod-api"
  cognito_user_pool_arns = ["arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_EXAMPLE1"]
  web_acl_arn            = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/acme-prod-regional/11111111-2222-3333-4444-555555555555"

  usage_plans = {
    basic = { rate_limit = 10, burst_limit = 20, quota_limit = 100000 }
    pro   = { rate_limit = 100, burst_limit = 200 }
  }
}

run "regional_api_with_strict_tls" {
  command = plan

  assert {
    condition = (
      aws_api_gateway_rest_api.this.name == "acme-prod-api" &&
      toset(aws_api_gateway_rest_api.this.endpoint_configuration[0].types) == toset(["REGIONAL"]) &&
      aws_api_gateway_rest_api.this.security_policy == "SecurityPolicy_TLS13_1_2_2021_06" &&
      aws_api_gateway_rest_api.this.endpoint_access_mode == "STRICT"
    )
    error_message = "REST API regional con TLS 1.3/1.2 y acceso STRICT."
  }

  assert {
    condition     = aws_api_gateway_rest_api.this.api_key_source == "HEADER" && aws_api_gateway_rest_api.this.minimum_compression_size == "1024"
    error_message = "API keys por cabecera y compresión a partir de 1 KB."
  }
}

run "every_method_requires_cognito_token_and_api_key" {
  command = plan

  assert {
    condition = (
      toset(keys(aws_api_gateway_method.any)) == toset(["root", "proxy"]) &&
      alltrue([for m in aws_api_gateway_method.any : m.http_method == "ANY" && m.authorization == "COGNITO_USER_POOLS" && m.api_key_required])
    )
    error_message = "ANY en / y /{proxy+} con autorizador de Cognito y API key."
  }

  assert {
    condition = (
      aws_api_gateway_authorizer.cognito.type == "COGNITO_USER_POOLS" &&
      aws_api_gateway_authorizer.cognito.identity_source == "method.request.header.Authorization" &&
      toset(aws_api_gateway_authorizer.cognito.provider_arns) == toset(["arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_EXAMPLE1"])
    )
    error_message = "El autorizador valida tokens de los user pools declarados en la cabecera Authorization."
  }

  assert {
    condition     = alltrue([for m in aws_api_gateway_method.any : m.authorization_scopes == null])
    error_message = "Sin authorization_scopes no se exigen scopes (ID token)."
  }

  assert {
    condition     = aws_api_gateway_resource.proxy.path_part == "{proxy+}" && aws_api_gateway_method.any["proxy"].request_parameters["method.request.path.proxy"]
    error_message = "Recurso proxy codicioso con su parámetro de ruta."
  }
}

run "lambda_proxy_integration_and_permission" {
  command = plan

  assert {
    condition = alltrue([
      for i in aws_api_gateway_integration.any :
      i.type == "AWS_PROXY" && i.integration_http_method == "POST" && i.timeout_milliseconds == 29000 &&
      i.uri == "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:acme-prod-api/invocations"
    ])
    error_message = "Integración Lambda proxy con el URI de invocación de la función."
  }

  assert {
    condition = (
      aws_lambda_permission.this.principal == "apigateway.amazonaws.com" &&
      aws_lambda_permission.this.source_account == "123456789012" &&
      aws_lambda_permission.this.source_arn == "arn:aws:execute-api:us-east-1:123456789012:a1b2c3d4e5/v1/*/*"
    )
    error_message = "Solo la etapa v1 de esta API puede invocar la función."
  }
}

run "stage_logs_and_method_settings" {
  command = plan

  assert {
    condition = (
      aws_api_gateway_stage.this.stage_name == "v1" &&
      aws_api_gateway_stage.this.xray_tracing_enabled == false &&
      jsondecode(aws_api_gateway_stage.this.access_log_settings[0].format).wafStatus == "$context.waf.status" &&
      !strcontains(aws_api_gateway_stage.this.access_log_settings[0].format, "header") &&
      !strcontains(aws_api_gateway_stage.this.access_log_settings[0].format, "apiKey\"")
    )
    error_message = "Etapa v1 sin X-Ray (OpenTelemetry), logs de acceso JSON con el estado de WAF y sin cabeceras ni la API key."
  }

  assert {
    condition = (
      aws_api_gateway_method_settings.all.method_path == "*/*" &&
      aws_api_gateway_method_settings.all.settings[0].data_trace_enabled == false &&
      aws_api_gateway_method_settings.all.settings[0].caching_enabled == false &&
      aws_api_gateway_method_settings.all.settings[0].logging_level == "ERROR" &&
      aws_api_gateway_method_settings.all.settings[0].metrics_enabled &&
      aws_api_gateway_method_settings.all.settings[0].throttling_rate_limit == 50
    )
    error_message = "Todos los métodos: métricas, logs de error sin cuerpos, sin caché y throttling por defecto."
  }

  assert {
    condition = (
      length(aws_cloudwatch_log_group.execution) == 1 &&
      aws_cloudwatch_log_group.execution[0].name == "API-Gateway-Execution-Logs_a1b2c3d4e5/v1" &&
      aws_cloudwatch_log_group.execution[0].kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555" &&
      aws_cloudwatch_log_group.access.retention_in_days == 90
    )
    error_message = "El log group de ejecución se crea antes que API Gateway, cifrado y con retención."
  }
}

run "usage_plans_per_tier" {
  command = plan

  assert {
    condition = (
      toset(keys(aws_api_gateway_usage_plan.this)) == toset(["basic", "pro"]) &&
      aws_api_gateway_usage_plan.this["basic"].throttle_settings[0].rate_limit == 10 &&
      aws_api_gateway_usage_plan.this["basic"].quota_settings[0].limit == 100000 &&
      aws_api_gateway_usage_plan.this["basic"].quota_settings[0].period == "MONTH" &&
      length(aws_api_gateway_usage_plan.this["pro"].quota_settings) == 0
    )
    error_message = "Un plan por tier con su throttling y cuota opcional."
  }

  assert {
    condition     = toset(keys(aws_ssm_parameter.this)) == toset(["rest_api_id", "invoke_url", "usage_plan_id/basic", "usage_plan_id/pro"])
    error_message = "SSM publica la API, la URL y los planes (nunca las API keys)."
  }
}

run "waf_is_associated_with_the_stage" {
  command = plan

  assert {
    condition     = aws_wafv2_web_acl_association.this[0].web_acl_arn == "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/acme-prod-regional/11111111-2222-3333-4444-555555555555"
    error_message = "El Web ACL regional se asocia a la etapa."
  }
}

run "no_cors_and_no_account_role_by_default" {
  command = plan

  assert {
    condition     = length(aws_api_gateway_method.options) == 0 && length(aws_api_gateway_gateway_response.cors) == 0
    error_message = "Sin cors_allow_origin no hay métodos OPTIONS ni cabeceras CORS."
  }

  assert {
    condition     = length(aws_api_gateway_account.this) == 0 && length(aws_iam_role.account_logging) == 0
    error_message = "El rol de CloudWatch de la cuenta es opcional."
  }
}

run "cors_preflight_and_error_responses" {
  command = plan

  variables {
    cors_allow_origin = "https://app.example.com"
  }

  assert {
    condition     = alltrue([for m in aws_api_gateway_method.options : m.authorization == "NONE" && m.api_key_required == false])
    error_message = "El preflight OPTIONS no lleva autorizador ni API key."
  }

  assert {
    condition     = alltrue([for i in aws_api_gateway_integration.options : i.type == "MOCK"])
    error_message = "El preflight responde con MOCK sin invocar la Lambda."
  }

  assert {
    condition = alltrue([
      for r in aws_api_gateway_integration_response.options :
      r.response_parameters["method.response.header.Access-Control-Allow-Origin"] == "'https://app.example.com'"
    ])
    error_message = "El preflight devuelve el origen exacto del frontend."
  }

  assert {
    condition = (
      toset(keys(aws_api_gateway_gateway_response.cors)) == toset(["DEFAULT_4XX", "DEFAULT_5XX"]) &&
      aws_api_gateway_gateway_response.cors["DEFAULT_4XX"].response_parameters["gatewayresponse.header.Access-Control-Allow-Origin"] == "'https://app.example.com'"
    )
    error_message = "Las respuestas de error de API Gateway llevan la cabecera CORS."
  }
}

run "scopes_switch_to_access_tokens" {
  command = plan

  variables {
    authorization_scopes = ["api/read"]
  }

  assert {
    condition     = alltrue([for m in aws_api_gateway_method.any : toset(m.authorization_scopes) == toset(["api/read"])])
    error_message = "Con scopes, todos los métodos los exigen."
  }
}

run "account_logging_role_for_apigateway_of_this_account" {
  command = plan

  variables {
    manage_account_logging_role = true
  }

  assert {
    condition = (
      length(aws_api_gateway_account.this) == 1 &&
      aws_iam_role_policy_attachment.account_logging[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
    )
    error_message = "Rol de CloudWatch de API Gateway con la política gestionada y fijado en la cuenta."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.account_logging_assume[0].statement :
      alltrue([for p in s.principals : toset(p.identifiers) == toset(["apigateway.amazonaws.com"])]) &&
      length([for c in s.condition : c if c.variable == "aws:SourceAccount" && toset(c.values) == toset(["123456789012"])]) == 1
    ])
    error_message = "Solo API Gateway de esta cuenta asume el rol."
  }
}

run "execution_logs_can_be_disabled" {
  command = plan

  variables {
    logging_level = "OFF"
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.execution) == 0 && aws_api_gateway_method_settings.all.settings[0].logging_level == "OFF"
    error_message = "Con logging_level OFF no hay logs de ejecución."
  }
}

run "origin_for_cloudfront" {
  command = apply

  assert {
    condition     = output.origin_domain_name == "a1b2c3d4e5.execute-api.us-east-1.amazonaws.com" && output.origin_path == "/v1"
    error_message = "Dominio y origin_path del origen /api/* de CloudFront."
  }
}

run "rejects_missing_waf_in_prod" {
  command = plan

  variables {
    web_acl_arn = null
  }

  expect_failures = [var.web_acl_arn]
}

run "rejects_cloudfront_scoped_waf" {
  command = plan

  variables {
    web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/acme-prod-cloudfront/11111111-2222-3333-4444-555555555555"
  }

  expect_failures = [var.web_acl_arn]
}

run "rejects_api_keys_without_usage_plans" {
  command = plan

  variables {
    usage_plans = {}
  }

  expect_failures = [var.usage_plans]
}

run "rejects_invalid_quota_period" {
  command = plan

  variables {
    usage_plans = { basic = { rate_limit = 10, burst_limit = 20, quota_limit = 100, quota_period = "YEAR" } }
  }

  expect_failures = [var.usage_plans]
}

run "rejects_wildcard_cors" {
  command = plan

  variables {
    cors_allow_origin = "*"
  }

  expect_failures = [var.cors_allow_origin]
}

run "rejects_legacy_tls_policy" {
  command = plan

  variables {
    security_policy = "TLS_1_0"
  }

  expect_failures = [var.security_policy]
}

run "rejects_non_cognito_authorizer_arn" {
  command = plan

  variables {
    cognito_user_pool_arns = ["arn:aws:iam::123456789012:role/foo"]
  }

  expect_failures = [var.cognito_user_pool_arns]
}

run "rejects_long_integration_timeout" {
  command = plan

  variables {
    integration_timeout_milliseconds = 60000
  }

  expect_failures = [var.integration_timeout_milliseconds]
}

run "web_acl_flag_controls_the_association" {
  command = plan

  variables {
    web_acl_arn     = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/acme-dev/abcd"
    web_acl_enabled = true
  }

  assert {
    condition     = length(aws_wafv2_web_acl_association.this) == 1
    error_message = "web_acl_enabled = true asocia el Web ACL (aunque su ARN se calcule en el mismo apply)."
  }
}

run "rejects_web_acl_flag_without_arn" {
  command = plan

  variables {
    environment     = "dev"
    web_acl_arn     = null
    web_acl_enabled = true
  }

  expect_failures = [var.web_acl_enabled]
}
