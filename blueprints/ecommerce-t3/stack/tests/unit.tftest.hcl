# Pruebas unitarias del blueprint (mock_provider, sin coste). Verifican la composición: qué módulos se
# instancian según las opciones, el cableado entre ellos y los valores por entorno. La lógica de cada
# módulo ya la prueban sus propios tests.

mock_provider "aws" {
  mock_resource "aws_cloudfront_function" {
    defaults = { arn = "arn:aws:cloudfront::123456789012:function/acme-dev-spa-routing" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/acme-dev-mock" }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-0123456789abcdef0" }
  }
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_subnet" {
    defaults = { id = "subnet-0123456789abcdef0" }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-api"
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:acme-dev-api/invocations"
    }
  }
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      id            = "a1b2c3d4e5"
      api_endpoint  = "https://a1b2c3d4e5.execute-api.us-east-1.amazonaws.com"
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:a1b2c3d4e5"
    }
  }
  mock_resource "aws_cognito_user_pool" {
    defaults = {
      id       = "us-east-1_EXAMPLE1"
      arn      = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_EXAMPLE1"
      endpoint = "cognito-idp.us-east-1.amazonaws.com/us-east-1_EXAMPLE1"
    }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/mock" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms" }
  }
  mock_resource "aws_cloudwatch_event_bus" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:event-bus/acme-dev-events" }
  }
  mock_resource "aws_backup_vault" {
    defaults = { arn = "arn:aws:backup:us-east-1:123456789012:backup-vault:acme-dev-backup" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::acme-dev-mock-123456789012" }
  }
  mock_resource "aws_rds_cluster" {
    defaults = {
      arn                 = "arn:aws:rds:us-east-1:123456789012:cluster:acme-dev-aurora"
      cluster_resource_id = "cluster-ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      master_user_secret = [{
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-abc-AbCdEf"
        secret_status = "active"
      }]
    }
  }
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = { RotationLambdaARN = "arn:aws:lambda:us-east-1:123456789012:function:acme-dev-aurora-rotation" }
    }
  }
}

mock_provider "aws" {
  alias = "us_east_1"

  mock_resource "aws_cloudfront_function" {
    defaults = { arn = "arn:aws:cloudfront::123456789012:function/acme-dev-spa-routing" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/99999999-2222-3333-4444-555555555555" }
  }
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
      domain_validation_options = [{
        domain_name           = "shop.example.com"
        resource_record_name  = "_abc.shop.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_xyz.acm-validations.aws."
      }]
    }
  }
  mock_resource "aws_wafv2_web_acl" {
    defaults = { arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/acme-dev/abcd" }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn            = "arn:aws:cloudfront::123456789012:distribution/E1ABCDEFGHIJKL"
      domain_name    = "d111111abcdef8.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }
  mock_resource "aws_cloudwatch_log_delivery_destination" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:delivery-destination:mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/mock" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:123456789012:acme-dev-edge-alarms" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::acme-dev-edge-logs-123456789012" }
  }
}

# El token origin-verify debe ser conocido en el plan: el mock compone mal bloques con valores desconocidos.
mock_provider "random" {
  mock_resource "random_password" {
    defaults = { result = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKL" }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  domain_name = "shop.example.com"
  zone_id     = "Z0123456789ABCDEFGHIJ"

  api_function = {
    s3_bucket = "acme-dev-artifacts"
    s3_key    = "api/app.zip"
  }
}

run "dynamodb_is_the_default_database" {
  command = plan

  assert {
    condition     = length(module.table) == 1 && length(module.aurora) == 0 && length(module.vpc) == 0 && length(module.endpoints) == 0
    error_message = "Por defecto la tienda usa DynamoDB y no crea VPC ni Aurora."
  }

  assert {
    condition     = contains(keys(local.api_environment), "TABLE_NAME") && !contains(keys(local.api_environment), "DB_CLUSTER_ARN")
    error_message = "La Lambda debe recibir el nombre de la tabla y no los datos de Aurora."
  }

  assert {
    condition     = toset(keys(local.api_policies)) == toset(["origin-verify", "events", "dynamodb"])
    error_message = "El rol de la Lambda solo lleva verificación de origen, publicación de eventos y la tabla."
  }

  assert {
    condition     = length(module.viewer_certificate) == 1
    error_message = "Sin viewer_certificate_arn el blueprint emite el certificado en la zona de Route 53."
  }
}

run "dev_uses_cheap_settings" {
  command = plan

  assert {
    condition     = local.log_retention_days == 30 && local.backup_schedule.daily_retention_days == 7 && local.backup_schedule.continuous_retention_days == 0
    error_message = "Fuera de prod: logs 30 días y backups cortos sin regla continua."
  }

  assert {
    condition     = local.monitored_waf["edge"].web_acl_name != null && length(local.monitored_cdn) == 1
    error_message = "El WAF y la distribución deben vigilarse."
  }
}

run "aurora_data_api_option" {
  command = plan

  variables {
    database = "aurora_data_api"
    aurora = {
      az_names = ["us-east-1a", "us-east-1b"]
    }
  }

  assert {
    condition     = length(module.aurora) == 1 && length(module.vpc) == 1 && length(module.endpoints) == 1 && length(module.table) == 0
    error_message = "La opción B crea VPC solo de datos, endpoint de Secrets Manager y Aurora, sin tabla."
  }

  assert {
    condition     = local.aurora_min_capacity == 0
    error_message = "Fuera de prod Aurora Serverless v2 se auto-pausa (min_capacity = 0)."
  }

  assert {
    condition     = contains(keys(local.api_policies), "data-api") && !contains(keys(local.api_policies), "dynamodb")
    error_message = "Con Aurora la Lambda usa la Data API, no DynamoDB."
  }

  assert {
    condition     = local.api_environment["DB_SECRET_ARN"] == module.aurora[0].app_secret_arn
    error_message = "La Lambda usa el secreto app_runtime, nunca el maestro."
  }
}

run "aurora_requires_az_names" {
  command = plan

  variables {
    database = "aurora_data_api"
  }

  expect_failures = [var.aurora]
}

run "requires_zone_or_certificate" {
  command = plan

  variables {
    zone_id = null
  }

  expect_failures = [var.viewer_certificate_arn]
}

run "external_certificate_skips_acm" {
  command = plan

  variables {
    zone_id                = null
    viewer_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/aaaaaaaa-2222-3333-4444-555555555555"
  }

  assert {
    condition     = length(module.viewer_certificate) == 0 && local.viewer_certificate_arn == "arn:aws:acm:us-east-1:123456789012:certificate/aaaaaaaa-2222-3333-4444-555555555555"
    error_message = "Con un certificado externo no se crea otro en ACM."
  }
}

run "flat_rate_plan_has_no_web_acl" {
  command = plan

  variables {
    waf_mode = "flat_rate"
  }

  assert {
    condition     = module.waf.web_acl_arn == null && length(local.monitored_waf) == 0
    error_message = "Con el plan flat-rate el WAF no se gestiona aquí ni se vigila su Web ACL."
  }
}

run "prod_tightens_retention_and_capacity" {
  command = plan

  variables {
    environment  = "prod"
    database     = "aurora_data_api"
    alarm_emails = ["ops@example.com"]
    aurora = {
      az_names = ["us-east-1a", "us-east-1b"]
    }
    auth = {
      email = {
        sending_account    = "DEVELOPER"
        source_arn         = "arn:aws:ses:us-east-1:123456789012:identity/example.com"
        from_email_address = "no-reply@example.com"
      }
    }
  }

  assert {
    condition     = local.log_retention_days == 365 && local.backup_schedule.daily_retention_days == 35 && local.aurora_min_capacity == 0.5
    error_message = "En prod: logs 1 año, backups de 35 días y Aurora sin auto-pausa."
  }
}

run "rejects_api_function_without_code" {
  command = plan

  variables {
    api_function = {}
  }

  expect_failures = [var.api_function]
}
