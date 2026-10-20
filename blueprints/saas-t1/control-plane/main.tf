# Control plane de SaaS T1 (SaaS Lens): identidad, registro de tenants, onboarding y metering. Vive en su
# propia cuenta; el app plane valida los JWT de estos pools y le envía los eventos de uso.
module "kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "control-plane"
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
    "s3.${local.region}.amazonaws.com",
    "firehose.${local.region}.amazonaws.com",
    "sqs.${local.region}.amazonaws.com",
  ]

  tags = var.tags
}

module "pools" {
  source   = "../../../modules/identity/cognito-user-pool"
  for_each = toset(var.pools)

  project     = var.project
  environment = var.environment
  name        = "${local.pool_prefix}-${each.key}"
  kms_key_arn = module.kms.key_arn

  feature_plan        = var.auth.feature_plan
  tenant_id_attribute = true

  groups = {
    tenant-admins = { description = "Administradores de su tenant", precedence = 10 }
  }

  app_clients = {
    web = {
      callback_urls = var.auth.callback_urls
      logout_urls   = var.auth.logout_urls
    }
  }

  email              = var.auth.email
  log_retention_days = local.log_retention_days

  tags = merge(var.tags, var.pool_strategy == "per_tenant" ? { Tenant = each.key } : null)
}

module "registry" {
  source = "../../../modules/data/dynamodb-table"

  project     = var.project
  environment = var.environment
  name        = "tenant-registry"
  kms_key_arn = module.kms.key_arn

  attributes = { tenant_id = "S", tier = "S" }
  hash_key   = "tenant_id"

  global_secondary_indexes = {
    by-tier = { hash_key = "tier", projection_type = "KEYS_ONLY" }
  }

  tags = merge(var.tags, { BackupPlan = local.tier })
}

# Clave privada de la GitHub App que dispara el pipeline de los silos: el secreto se crea vacío y el valor
# se carga a mano (nunca en el código ni en el estado).
resource "aws_secretsmanager_secret" "github_app" {
  count = var.silo_pipeline == null ? 0 : 1

  name                    = "${local.name}-github-app"
  description             = "Clave privada de la GitHub App del pipeline de tenants silo (se carga a mano)"
  kms_key_id              = module.kms.key_arn
  recovery_window_in_days = local.prod ? 30 : 0

  tags = var.tags
}

module "onboarding" {
  source = "../../../modules/compute/lambda-function"

  project     = var.project
  environment = var.environment
  name        = "onboarding"
  kms_key_arn = module.kms.key_arn

  runtime           = var.onboarding_function.image_uri == null ? var.onboarding_function.runtime : null
  handler           = var.onboarding_function.image_uri == null ? var.onboarding_function.handler : null
  s3_bucket         = var.onboarding_function.s3_bucket
  s3_key            = var.onboarding_function.s3_key
  s3_object_version = var.onboarding_function.s3_object_version
  image_uri         = var.onboarding_function.image_uri
  timeout_seconds   = var.onboarding_function.timeout_seconds

  environment_variables = local.onboarding_environment
  log_retention_days    = local.log_retention_days
  enable_dlq            = true

  policies = local.onboarding_policies

  tags = var.tags
}

# Metering: el app plane publica eventos saas.usage en el bus; Firehose los guarda particionados por tenant.
module "metering_bucket" {
  source = "../../../modules/storage/s3-bucket"

  project       = var.project
  environment   = var.environment
  purpose       = "data"
  bucket_name   = "${local.name}-metering-${local.account_id}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = !local.prod

  lifecycle_config = {
    transition_to_ia_days = 30
  }

  tags = var.tags
}

module "metering_stream" {
  source = "../../../modules/integration/firehose-to-s3"

  project            = var.project
  environment        = var.environment
  name               = "metering"
  bucket_arn         = module.metering_bucket.bucket_arn
  kms_key_arn        = module.kms.key_arn
  prefix             = "usage/"
  log_retention_days = local.log_retention_days

  buffer               = { interval_seconds = 300, size_mb = 64 }
  dynamic_partitioning = { key_name = "tenant_id", jq_query = ".detail.tenant_id" }

  publish_ssm_parameters = false

  tags = var.tags
}

module "events" {
  source = "../../../modules/integration/eventbridge-bus"

  project                = var.project
  environment            = var.environment
  name                   = "${local.name}-control-plane"
  kms_key_arn            = module.kms.key_arn
  archive_retention_days = local.prod ? 30 : 7
  publisher_account_ids  = var.app_account_ids

  # Las rutas /integration/ de SSM son la interfaz del app plane: el control plane publica las suyas en
  # /control-plane/ (y así ambos pueden convivir en una cuenta, como en la sandbox).
  publish_ssm_parameters = false

  rules = {
    usage = {
      firehose_arn    = module.metering_stream.delivery_stream_arn
      description     = "Eventos de uso por tenant (metering y facturacion)"
      source_prefixes = ["saas.usage"]
    }
  }

  tags = var.tags
}

module "alarms" {
  source = "../../../modules/observability/alarms"

  project             = var.project
  environment         = var.environment
  name                = "${local.name}-cp"
  kms_key_arn         = module.kms.key_arn
  email_subscriptions = var.alarm_emails

  lambda_functions = { onboarding = { function_name = module.onboarding.function_name, timeout_seconds = var.onboarding_function.timeout_seconds } }
  dynamodb_tables  = { registry = { table_name = module.registry.table_name } }

  tags = var.tags
}

module "dashboard" {
  source = "../../../modules/observability/dashboard"

  project     = var.project
  environment = var.environment
  name        = "${local.name}-control-plane"
  alarm_arns  = module.alarms.alarm_arns

  lambda_functions = { onboarding = { function_name = module.onboarding.function_name } }
  dynamodb_tables  = { registry = { table_name = module.registry.table_name } }
}

module "backup_kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "cp-backup"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.${local.region}.amazonaws.com"]

  tags = var.tags
}

module "backup" {
  source = "../../../modules/resilience/backup-plan"

  project       = var.project
  environment   = var.environment
  name          = "cp-backup"
  kms_key_arn   = module.backup_kms.key_arn
  tier          = local.tier
  schedule      = local.backup_schedule
  vault_lock    = local.prod ? { min_retention_days = 7, changeable_for_days = 3 } : null
  alarm_actions = [module.alarms.topic_arn]

  publish_ssm_parameters = false

  tags = var.tags
}

resource "aws_ssm_parameter" "layer" {
  for_each = local.ssm_parameters

  name  = "/${var.project}/${var.environment}/control-plane/${each.key}"
  type  = each.key == "issuers" ? "StringList" : "String"
  value = each.value

  tags = var.tags
}
