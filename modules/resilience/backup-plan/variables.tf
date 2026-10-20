variable "project" {
  description = "Nombre del proyecto; prefijo de los nombres de recursos."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project debe ser minúsculas, dígitos y guiones (2-21 caracteres), empezando por letra."
  }

  nullable = false
}

variable "environment" {
  description = "Entorno de despliegue."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "name" {
  description = "Nombre lógico del vault y del plan; los reales son <project>-<environment>-<name>."
  type        = string
  default     = "backup"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-20 caracteres), empezando por letra."
  }

  nullable = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK propia del vault (no la clave de los datos de origen). En una cuenta o región de destino de copias, la clave de esa región. Su política debe autorizar a AWS Backup (kms:ViaService de backup)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "plan_enabled" {
  description = "Crea el plan, la selección y el rol de servicio además del vault. false = solo vault (y su bloqueo): es el modo para el vault de destino de las copias en otra región o en la cuenta de backup, que se despliega instanciando este módulo allí."
  type        = bool
  default     = true
  nullable    = false
}

variable "tier" {
  description = "Valor de la etiqueta BackupPlan que selecciona los recursos a proteger (enterprise, growth o starter): los módulos de datos la ponen con backup_plan. Obligatorio con plan_enabled = true."
  type        = string
  default     = null

  validation {
    condition     = var.tier == null || contains(["enterprise", "growth", "starter"], var.tier)
    error_message = "tier debe ser enterprise, growth o starter."
  }

  validation {
    condition     = !var.plan_enabled || var.tier != null
    error_message = "Con plan_enabled = true hay que indicar tier."
  }
}

variable "schedule" {
  description = "Reglas del plan: diaria (daily_retention_days), mensual (monthly_retention_days, con paso a almacenamiento frío tras monthly_cold_storage_after_days; 0 lo desactiva; solo aplica a los tipos de recurso que lo admiten) y continua (continuous_retention_days, 1-35, para recuperación a un punto en el tiempo de Aurora/RDS/S3; 0 desactiva la regla). Horas en UTC."
  type = object({
    daily_retention_days            = optional(number, 35)
    monthly_retention_days          = optional(number, 365)
    monthly_cold_storage_after_days = optional(number, 30)
    continuous_retention_days       = optional(number, 35)
    daily_cron                      = optional(string, "cron(0 5 * * ? *)")
    monthly_cron                    = optional(string, "cron(0 5 1 * ? *)")
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.schedule.daily_retention_days >= 1 && var.schedule.monthly_retention_days >= 1
    error_message = "Las retenciones diaria y mensual deben ser de al menos 1 día."
  }

  validation {
    condition     = var.schedule.continuous_retention_days >= 0 && var.schedule.continuous_retention_days <= 35
    error_message = "continuous_retention_days debe estar entre 0 (sin regla continua) y 35."
  }

  validation {
    condition     = var.schedule.monthly_cold_storage_after_days == 0 || var.schedule.monthly_retention_days >= var.schedule.monthly_cold_storage_after_days + 90
    error_message = "AWS Backup exige que la retención mensual supere en al menos 90 días el paso a almacenamiento frío."
  }

  validation {
    condition     = can(regex("^cron\\(.+\\)$", var.schedule.daily_cron)) && can(regex("^cron\\(.+\\)$", var.schedule.monthly_cron))
    error_message = "daily_cron y monthly_cron deben tener el formato cron(...) de EventBridge."
  }

  validation {
    condition     = var.environment != "prod" || var.schedule.daily_retention_days >= 14
    error_message = "En prod la retención diaria debe ser de al menos 14 días."
  }

  validation {
    condition = var.vault_lock == null || min(concat(
      [var.schedule.daily_retention_days, var.schedule.monthly_retention_days],
      var.schedule.continuous_retention_days > 0 ? [var.schedule.continuous_retention_days] : [],
    )...) >= var.vault_lock.min_retention_days
    error_message = "Todas las retenciones deben ser al menos vault_lock.min_retention_days: el bloqueo del vault rechaza ciclos de vida más cortos."
  }
}

variable "copy_destinations" {
  description = "Vaults de destino de las copias de las reglas diaria y mensual, por clave estable (p. ej. dr, backup-account): el vault de otra región (DR) o de la cuenta de backup, creado instanciando este módulo allí con plan_enabled = false. retention_days null = la retención de cada regla."
  type = map(object({
    vault_arn      = string
    retention_days = optional(number)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for d in values(var.copy_destinations) : can(regex("^arn:[a-z-]+:backup:[a-z0-9-]+:[0-9]{12}:backup-vault:[a-zA-Z0-9_-]{2,50}$", d.vault_arn))])
    error_message = "vault_arn debe ser el ARN de un vault de AWS Backup."
  }

  validation {
    condition     = alltrue([for d in values(var.copy_destinations) : d.retention_days == null || d.retention_days >= 1])
    error_message = "retention_days debe ser al menos 1."
  }

  validation {
    condition     = length(var.copy_destinations) == 0 || var.plan_enabled
    error_message = "copy_destinations solo tiene sentido con plan_enabled = true."
  }
}

variable "allow_copy_from_account_ids" {
  description = "Cuentas autorizadas a copiar recovery points a este vault (política del vault de destino: backup:CopyIntoBackupVault). Vacío = sin política."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for a in var.allow_copy_from_account_ids : can(regex("^[0-9]{12}$", a))])
    error_message = "Cada cuenta debe ser un ID de 12 dígitos."
  }
}

variable "vault_lock" {
  description = "Bloqueo del vault en modo compliance (con changeable_for_days >= 3): durante esos días de enfriamiento se puede deshacer; después es IRREVERSIBLE y ni la raíz de la cuenta puede borrar recovery points antes de min_retention_days ni retirar el bloqueo. Obligatorio en prod para los tiers enterprise y growth. max_retention_days null = sin máximo."
  type = object({
    min_retention_days  = optional(number, 7)
    max_retention_days  = optional(number)
    changeable_for_days = optional(number, 3)
  })
  default = null

  validation {
    condition     = var.vault_lock == null || (var.vault_lock.changeable_for_days >= 3 && var.vault_lock.changeable_for_days <= 36500)
    error_message = "changeable_for_days debe estar entre 3 y 36500: con menos de 3 el bloqueo sería de gobernanza, no de compliance."
  }

  validation {
    condition     = var.vault_lock == null || var.vault_lock.min_retention_days >= 1
    error_message = "min_retention_days debe ser al menos 1."
  }

  validation {
    condition     = var.vault_lock == null || var.vault_lock.max_retention_days == null || var.vault_lock.max_retention_days >= var.vault_lock.min_retention_days
    error_message = "max_retention_days debe ser mayor o igual que min_retention_days."
  }

  validation {
    condition     = var.environment != "prod" || !contains(["enterprise", "growth"], coalesce(var.tier, "starter")) || var.vault_lock != null
    error_message = "En prod los tiers enterprise y growth deben bloquear el vault (vault_lock)."
  }
}

variable "restore_testing" {
  description = "Pruebas de restauración automáticas (T1): plan periódico que restaura el último recovery point de cada tipo y lo da por válido tras validation_window_hours. metadata_overrides, por tipo (Aurora, RDS, DynamoDB), son los parámetros de la restauración, que las bases de datos necesitan para no caer en la VPC por defecto: p. ej. Aurora { dbsubnetgroupname = ..., vpcsecuritygroupids = jsonencode([...]) }. Requiere plan_enabled."
  type = object({
    schedule_expression     = optional(string, "cron(0 6 1 * ? *)")
    recovery_window_days    = optional(number, 30)
    validation_window_hours = optional(number, 1)
    resource_types          = optional(list(string), ["Aurora", "RDS", "DynamoDB"])
    metadata_overrides      = optional(map(map(string)), {})
    start_window_hours      = optional(number, 8)
  })
  default = null

  validation {
    condition     = var.restore_testing == null || var.plan_enabled
    error_message = "restore_testing requiere plan_enabled = true."
  }

  validation {
    condition     = var.restore_testing == null || alltrue([for t in var.restore_testing.resource_types : contains(["Aurora", "RDS", "DynamoDB", "EFS", "S3", "EBS", "EC2"], t)])
    error_message = "resource_types debe contener tipos admitidos por las pruebas de restauración (Aurora, RDS, DynamoDB, EFS, S3, EBS, EC2)."
  }

  validation {
    condition     = var.restore_testing == null || (var.restore_testing.validation_window_hours >= 1 && var.restore_testing.validation_window_hours <= 168)
    error_message = "validation_window_hours debe estar entre 1 y 168."
  }

  validation {
    condition     = var.restore_testing == null || (var.restore_testing.recovery_window_days >= 1 && var.restore_testing.recovery_window_days <= 365)
    error_message = "recovery_window_days debe estar entre 1 y 365."
  }

  validation {
    condition     = var.restore_testing == null || can(regex("^cron\\(.+\\)$", var.restore_testing.schedule_expression))
    error_message = "schedule_expression debe tener el formato cron(...)."
  }
}

variable "alarm_actions" {
  description = "ARN de los topics de SNS que reciben las alarmas de trabajos fallidos (topic_arn de observability/alarms). Vacío crea las alarmas sin notificación (visibles solo en la consola)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "publish_ssm_parameters" {
  description = "Publica el nombre y el ARN del vault en SSM Parameter Store bajo /<project>/<env>/resilience/ para las capas consumidoras."
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
