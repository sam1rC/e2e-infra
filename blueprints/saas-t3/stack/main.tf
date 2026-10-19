# CMK del entorno (región de la aplicación): logs, tabla, secretos y topic de alarmas.
module "kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "app"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = [
    "logs.${local.region}.amazonaws.com",
    "cloudwatch.amazonaws.com",
    "sns.amazonaws.com",
  ]
  via_services = [
    "dynamodb.${local.region}.amazonaws.com",
    "secretsmanager.${local.region}.amazonaws.com",
  ]

  tags = var.tags
}

# Token de verificación de origen (ADR 0010): CloudFront lo añade al origen /api/* y el WAF regional de la
# etapa bloquea lo que no lo lleve. También queda en Secrets Manager para que la Lambda lo compruebe si se
# quiere defensa en profundidad.
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

# User pool compartido (pool): el tenant va en custom:tenant_id, que solo asigna el onboarding.
module "tenants" {
  source = "../../../modules/identity/cognito-user-pool"

  project     = var.project
  environment = var.environment
  name        = "tenants"
  kms_key_arn = module.kms.key_arn

  tenant_id_attribute = true

  groups = {
    tenant-admins = { description = "Administradores de su tenant", precedence = 10 }
  }

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

# Tabla pool con aislamiento por partición (ADR 0006): la clave de partición es tenant_id.
module "table" {
  source = "../../../modules/data/dynamodb-table"

  project     = var.project
  environment = var.environment
  name        = "tenant-data"
  kms_key_arn = module.kms.key_arn

  attributes           = { tenant_id = "S", sk = "S" }
  hash_key             = "tenant_id"
  range_key            = "sk"
  tenant_partition_key = true
  ttl_attribute        = "expires_at"

  tags = merge(var.tags, { BackupPlan = local.tier })
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

# Token vending machine: rol que la Lambda asume con la etiqueta de sesión del tenant.
module "tenant_role" {
  source = "../../../modules/identity/tenant-access-role"

  project           = var.project
  environment       = var.environment
  trusted_role_arns = [module.api_function.role_arn]

  dynamodb_tables = {
    data = { table_arn = module.table.table_arn }
  }

  tags = var.tags
}

# WAF regional de la etapa: reglas gestionadas + bloqueo de lo que no llegue por CloudFront.
module "api_waf" {
  source = "../../../modules/edge/waf-web-acl"

  project     = var.project
  environment = var.environment
  scope       = "REGIONAL"

  managed_rules_mode = coalesce(var.waf_rules_mode, var.environment == "dev" ? "count" : "block")
  origin_verify      = { secret = random_password.origin_verify.result }
  log_kms_key_arn    = module.kms.key_arn
  log_retention_days = local.log_retention_days

  tags = var.tags
}

module "api" {
  source = "../../../modules/api/apigw-rest"

  project     = var.project
  environment = var.environment
  name        = "api"
  kms_key_arn = module.kms.key_arn

  lambda_function_arn    = module.api_function.function_arn
  cognito_user_pool_arns = [module.tenants.user_pool_arn]
  usage_plans            = var.usage_plans
  web_acl_arn            = module.api_waf.web_acl_arn
  web_acl_enabled        = true # el Web ACL se crea en este mismo apply

  manage_account_logging_role = var.manage_apigw_account_logging_role
  log_retention_days          = local.log_retention_days

  tags = var.tags
}

module "backup_kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "backup"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.${local.region}.amazonaws.com"]

  tags = var.tags
}

module "backup" {
  source = "../../../modules/resilience/backup-plan"

  project       = var.project
  environment   = var.environment
  kms_key_arn   = module.backup_kms.key_arn
  tier          = local.tier
  schedule      = local.backup_schedule
  alarm_actions = [module.alarms.topic_arn]

  tags = var.tags
}
