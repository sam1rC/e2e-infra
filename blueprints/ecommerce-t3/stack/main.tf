# CMK del entorno (región de la aplicación): logs, bus, colas, tabla, secretos, topic de alarmas.
module "kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "app"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = [
    "logs.${local.region}.amazonaws.com",
    "events.amazonaws.com",
    "sqs.amazonaws.com",
    "cloudwatch.amazonaws.com",
    "sns.amazonaws.com",
  ]
  via_services = [
    "dynamodb.${local.region}.amazonaws.com",
    "secretsmanager.${local.region}.amazonaws.com",
    "sqs.${local.region}.amazonaws.com",
    "s3.${local.region}.amazonaws.com",
    "rds.${local.region}.amazonaws.com",
  ]

  tags = var.tags
}

# Token de verificación de origen (ADR 0010): CloudFront lo añade al origen /api/* y la Lambda rechaza lo
# que no lo lleve (HTTP API no admite WAF). Queda en el estado cifrado; se rota subiendo
# origin_verify_version y la Lambda acepta AWSCURRENT y AWSPREVIOUS mientras CloudFront se propaga.
resource "random_password" "origin_verify" {
  length  = 48
  special = false

  keepers = {
    version = tostring(var.origin_verify_version)
  }
}

resource "aws_secretsmanager_secret" "origin_verify" {
  name                    = "${local.name}-origin-verify"
  description             = "Token x-origin-verify que CloudFront envia a la API (ADR 0010)"
  kms_key_id              = module.kms.key_arn
  recovery_window_in_days = local.prod ? 30 : 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "origin_verify" {
  secret_id                = aws_secretsmanager_secret.origin_verify.id
  secret_string_wo         = random_password.origin_verify.result
  secret_string_wo_version = var.origin_verify_version
}

module "events" {
  source = "../../../modules/integration/eventbridge-bus"

  project                = var.project
  environment            = var.environment
  kms_key_arn            = module.kms.key_arn
  archive_retention_days = local.prod ? 30 : 7

  tags = var.tags
}

module "customers" {
  source = "../../../modules/identity/cognito-user-pool"

  project     = var.project
  environment = var.environment
  name        = "customers"
  kms_key_arn = module.kms.key_arn

  self_registration_enabled = true

  app_clients = {
    web = {
      callback_urls = local.callback_urls
      logout_urls   = local.logout_urls
    }
  }

  domain             = var.auth.domain_prefix == null ? null : { prefix = var.auth.domain_prefix }
  email              = var.auth.email
  log_retention_days = local.log_retention_days

  tags = var.tags
}

module "api_function" {
  source = "../../../modules/compute/lambda-function"

  project     = var.project
  environment = var.environment
  name        = "api"
  kms_key_arn = module.kms.key_arn

  runtime           = var.api_function.image_uri == null ? var.api_function.runtime : null
  handler           = var.api_function.image_uri == null ? var.api_function.handler : null
  s3_bucket         = var.api_function.s3_bucket
  s3_key            = var.api_function.s3_key
  s3_object_version = var.api_function.s3_object_version
  image_uri         = var.api_function.image_uri

  memory_size           = var.api_function.memory_size
  timeout_seconds       = var.api_function.timeout_seconds
  environment_variables = merge(var.api_function.environment_variables, local.api_environment)
  log_retention_days    = local.log_retention_days

  policies = local.api_policies

  tags = var.tags
}

module "api" {
  source = "../../../modules/api/apigw-http"

  project     = var.project
  environment = var.environment
  name        = "api"
  kms_key_arn = module.kms.key_arn

  integrations = {
    api = { lambda_function_arn = module.api_function.function_arn }
  }

  routes = { for k, r in var.api_routes : k => merge(r, { integration = "api" }) }

  jwt_authorizer = {
    issuer   = module.customers.issuer_url
    audience = [module.customers.client_ids["web"]]
  }

  log_retention_days = local.log_retention_days

  tags = var.tags
}
