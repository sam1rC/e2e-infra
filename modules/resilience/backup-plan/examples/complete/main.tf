provider "aws" {
  region = "us-east-1"
}

# Región de DR: el vault de destino de las copias se crea instanciando el módulo allí.
provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "backup"

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.us-east-1.amazonaws.com"]
}

module "kms_dr" {
  source = "../../../../foundation/kms-key"

  providers = { aws = aws.dr }

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "backup"

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.us-west-2.amazonaws.com"]
}

module "kms_alarms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "alarms"

  service_principals = ["cloudwatch.amazonaws.com", "sns.amazonaws.com"]
}

module "alarms" {
  source = "../../../../observability/alarms"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  kms_key_arn = module.kms_alarms.key_arn
}

# Vault de destino (DR): solo vault, sin plan. En SaaS T1 se repite en la cuenta de backup con
# allow_copy_from_account_ids = [<cuenta de origen>].
module "vault_dr" {
  source = "../.."

  providers = { aws = aws.dr }

  project      = "acme-${var.name_suffix}"
  environment  = "dev"
  name         = "dr"
  kms_key_arn  = module.kms_dr.key_arn
  plan_enabled = false

  publish_ssm_parameters = false
}

# Vault de origen con copia a DR y pruebas de restauración. Sin vault_lock: el bloqueo en modo compliance
# es irreversible tras 3 días y no debe usarse en un ejemplo efímero (en prod T1/T2 es obligatorio).
module "backup" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  kms_key_arn = module.kms.key_arn
  tier        = "enterprise"

  schedule = {
    daily_retention_days            = 35
    monthly_retention_days          = 365
    monthly_cold_storage_after_days = 30
    continuous_retention_days       = 35
  }

  copy_destinations = {
    dr = { vault_arn = module.vault_dr.vault_arn }
  }

  restore_testing = {
    schedule_expression  = "cron(0 6 1 * ? *)"
    recovery_window_days = 30
    resource_types       = ["DynamoDB"]
  }

  alarm_actions = [module.alarms.topic_arn]
}

output "vault_arn" {
  description = "ARN del vault de origen."
  value       = module.backup.vault_arn
}

output "dr_vault_arn" {
  description = "ARN del vault de DR."
  value       = module.vault_dr.vault_arn
}
