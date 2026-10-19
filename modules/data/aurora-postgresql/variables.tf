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
  description = "Nombre del cluster. Si es null: <project>-<environment>-aurora."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-41 caracteres), empezando por letra."
  }
}

variable "vpc_id" {
  description = "VPC donde se crea el security group de la base de datos."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "subnet_ids" {
  description = "Subredes de la capa data (al menos 2, en AZ distintas) para el subnet group."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids necesita al menos 2 subredes (2 AZ)."
  }

  nullable = false
}

variable "allowed_security_group_ids" {
  description = "Security groups autorizados a conectar al puerto de PostgreSQL, como mapa nombre estable => ID. Un mapa (y no una lista) permite pasar IDs que aún no existen: las claves son conocidas al planificar. El SG de la base de datos no tiene reglas de salida."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK del entorno: cifra el almacenamiento, el secreto maestro, el secreto de la aplicación, Database Insights y el log group. Su política debe autorizar a rds.amazonaws.com vía kms:ViaService, a Secrets Manager y a logs.<región>.amazonaws.com (service_principals de foundation/kms-key)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "engine_version" {
  description = "Versión del motor Aurora PostgreSQL (p. ej. 17.11 o solo la mayor, 17). Verifica las disponibles con `aws rds describe-db-engine-versions --engine aurora-postgresql`. Con auto_minor_version_upgrade el minor puede avanzar fuera de OpenTofu. La familia del parameter group se deduce de la versión mayor."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{2}(\\.[0-9]+)?$", var.engine_version))
    error_message = "engine_version debe ser <mayor> o <mayor>.<minor> (p. ej. 17 o 17.5)."
  }

  nullable = false
}

variable "auto_minor_version_upgrade" {
  description = "Aplica automáticamente las actualizaciones menores en la ventana de mantenimiento."
  type        = bool
  default     = true
  nullable    = false
}

variable "capacity_mode" {
  description = "provisioned (clase de instancia fija) o serverless_v2 (ACU entre serverless_v2.min_capacity y max_capacity)."
  type        = string
  default     = "provisioned"

  validation {
    condition     = contains(["provisioned", "serverless_v2"], var.capacity_mode)
    error_message = "capacity_mode debe ser provisioned o serverless_v2."
  }

  nullable = false
}

variable "instance_class" {
  description = "Clase de instancia en modo provisioned (Graviton: db.t4g.medium en dev, db.r7g.large o mayor en prod). Se ignora en serverless_v2 (db.serverless)."
  type        = string
  default     = "db.t4g.medium"

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.instance_class))
    error_message = "instance_class debe tener el formato db.<familia>.<tamaño>."
  }

  nullable = false
}

variable "serverless_v2" {
  description = "Escalado de Aurora Serverless v2 (solo con capacity_mode = serverless_v2). min_capacity = 0 activa la auto-pausa tras seconds_until_auto_pause (300-86400) y exige una versión del motor que la soporte (verifícalo antes)."
  type = object({
    min_capacity             = optional(number, 0.5)
    max_capacity             = optional(number, 4)
    seconds_until_auto_pause = optional(number)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.serverless_v2.min_capacity >= 0 && var.serverless_v2.max_capacity <= 256 && var.serverless_v2.max_capacity >= max(var.serverless_v2.min_capacity, 1)
    error_message = "serverless_v2 necesita 0 <= min_capacity <= max_capacity <= 256 y max_capacity >= 1."
  }

  validation {
    condition     = alltrue([for c in [var.serverless_v2.min_capacity, var.serverless_v2.max_capacity] : c * 2 == floor(c * 2)])
    error_message = "serverless_v2.min_capacity y max_capacity deben ser múltiplos de 0.5."
  }

  validation {
    condition     = var.serverless_v2.seconds_until_auto_pause == null || (var.serverless_v2.min_capacity == 0 && var.serverless_v2.seconds_until_auto_pause >= 300 && var.serverless_v2.seconds_until_auto_pause <= 86400)
    error_message = "seconds_until_auto_pause solo aplica con min_capacity = 0 y debe estar entre 300 y 86400."
  }
}

variable "instance_count" {
  description = "Número de instancias (1 writer + lectores, repartidas en las AZ de az_names). null = 2 en prod y 1 en el resto."
  type        = number
  default     = null

  validation {
    condition     = var.instance_count == null || (var.instance_count >= 1 && var.instance_count <= 15)
    error_message = "instance_count debe estar entre 1 y 15."
  }

  validation {
    condition     = var.environment != "prod" || coalesce(var.instance_count, 2) >= 2
    error_message = "En prod se necesitan al menos 2 instancias (writer y lector en AZ distintas)."
  }
}

variable "az_names" {
  description = "AZ donde se reparten las instancias (en orden: la primera aloja el writer). null = Aurora elige. Deben coincidir con las AZ de subnet_ids."
  type        = list(string)
  default     = null

  validation {
    condition     = var.az_names == null || length(var.az_names) >= 2
    error_message = "az_names necesita al menos 2 AZ, o null."
  }
}

variable "promotion_tier" {
  description = "Prioridad de promoción a writer de las instancias lectoras (0-15; el writer inicial usa 0)."
  type        = number
  default     = 1

  validation {
    condition     = var.promotion_tier >= 0 && var.promotion_tier <= 15
    error_message = "promotion_tier debe estar entre 0 y 15."
  }

  nullable = false
}

variable "database_name" {
  description = "Base de datos inicial."
  type        = string
  default     = "app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name debe ser minúsculas, dígitos y guiones bajos, empezando por letra."
  }

  nullable = false
}

variable "master_username" {
  description = "Usuario maestro. Su contraseña la genera y rota RDS (secreto gestionado); es solo para administración y migraciones, la aplicación usa el secreto app_runtime."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,15}$", var.master_username)) && !contains(["postgres", "rdsadmin", "admin"], var.master_username)
    error_message = "master_username debe ser minúsculas/dígitos/guiones bajos (1-16, empezando por letra) y no postgres, rdsadmin ni admin."
  }

  nullable = false
}

variable "port" {
  description = "Puerto de PostgreSQL."
  type        = number
  default     = 5432

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "port debe estar entre 1024 y 65535."
  }

  nullable = false
}

variable "backup" {
  description = "Copia de seguridad nativa (PITR). retention_days null = 35 en prod y 7 en el resto (en prod, mínimo 14). Las ventanas no deben solaparse. Además, el cluster entra en el plan de AWS Backup por la etiqueta BackupPlan."
  type = object({
    retention_days     = optional(number)
    window             = optional(string, "03:00-04:00")
    maintenance_window = optional(string, "sun:05:00-sun:06:00")
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.backup.retention_days == null || (var.backup.retention_days >= 1 && var.backup.retention_days <= 35)
    error_message = "backup.retention_days debe estar entre 1 y 35."
  }

  validation {
    condition     = var.environment != "prod" || coalesce(var.backup.retention_days, 35) >= 14
    error_message = "En prod backup.retention_days debe ser al menos 14."
  }

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup.window))
    error_message = "backup.window debe tener el formato hh:mm-hh:mm (UTC)."
  }

  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup.maintenance_window))
    error_message = "backup.maintenance_window debe tener el formato ddd:hh:mm-ddd:hh:mm (UTC, en minúsculas)."
  }
}

variable "backup_plan" {
  description = "Valor de la etiqueta BackupPlan que selecciona el cluster en el plan de AWS Backup (fase 7.4), p. ej. el tier. null = sin etiqueta."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protección contra borrado. null = true en prod y en staging, false en dev. En prod no puede desactivarse."
  type        = bool
  default     = null

  validation {
    condition     = var.environment != "prod" || var.deletion_protection != false
    error_message = "En prod deletion_protection no puede ser false."
  }
}

variable "skip_final_snapshot" {
  description = "Omite la instantánea final al destruir. Solo permitido fuera de prod."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = var.environment != "prod" || !var.skip_final_snapshot
    error_message = "En prod no se puede omitir la instantánea final."
  }
}

variable "final_snapshot_identifier" {
  description = "Nombre de la instantánea final. null = <name>-final (si ya existe una con ese nombre, la destrucción falla: bórrala o cambia el nombre)."
  type        = string
  default     = null
}

variable "database_insights_mode" {
  description = "CloudWatch Database Insights: standard (7 días, incluido) o advanced (15 meses, de pago; exige retención de 465 días). Sustituye a Performance Insights, retirado el 30-jun-2026."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "advanced"], var.database_insights_mode)
    error_message = "database_insights_mode debe ser standard o advanced."
  }

  nullable = false
}

variable "monitoring_interval" {
  description = "Intervalo de Enhanced Monitoring en segundos (0 lo desactiva; en prod debe estar activo)."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval debe ser 0, 1, 5, 10, 15, 30 o 60."
  }

  validation {
    condition     = var.environment != "prod" || var.monitoring_interval > 0
    error_message = "En prod Enhanced Monitoring debe estar activo."
  }

  nullable = false
}

variable "log_retention_days" {
  description = "Retención del log group de PostgreSQL, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days debe ser un valor admitido por CloudWatch Logs (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, ...)."
  }

  validation {
    condition     = var.environment != "prod" || var.log_retention_days >= 90
    error_message = "En prod la retención de logs debe ser de al menos 90 días."
  }

  nullable = false
}

variable "log_min_duration_statement" {
  description = "Registra las consultas que duran más de este valor en milisegundos (-1 desactiva, 0 registra todas)."
  type        = number
  default     = 1000

  validation {
    condition     = var.log_min_duration_statement >= -1
    error_message = "log_min_duration_statement debe ser -1 o mayor."
  }

  nullable = false
}

variable "enable_http_endpoint" {
  description = "Activa la RDS Data API (HTTP). Solo para el patrón sin conexiones persistentes (E-commerce T3 opción B); las llamadas se autorizan por IAM + secreto."
  type        = bool
  default     = false
  nullable    = false
}

variable "apply_immediately" {
  description = "Aplica los cambios sin esperar a la ventana de mantenimiento (útil en dev; en prod mejor false)."
  type        = bool
  default     = false
  nullable    = false
}

variable "app_secret_rotation" {
  description = "Rotación multiusuario del secreto app_runtime (ver postgres-app-secret): subnet_ids (capa app), endpoint_security_group_id (SG del endpoint de Secrets Manager), automatically_after_days. Obligatoria en prod; null = solo el secreto vacío."
  type = object({
    subnet_ids                 = list(string)
    endpoint_security_group_id = string
    automatically_after_days   = optional(number, 30)
  })
  default = null
}

variable "app_secret_recovery_window_in_days" {
  description = "Ventana de recuperación del secreto app_runtime al borrarlo (7-30; 0 = borrado inmediato, solo fuera de prod). null = 30 en prod y 7 en el resto. La valida postgres-app-secret."
  type        = number
  default     = null
}

variable "publish_ssm_parameters" {
  description = "Publica endpoints y ARNs en SSM Parameter Store bajo /<project>/<env>/data/<ssm_namespace>/ para las capas consumidoras."
  type        = bool
  default     = true
  nullable    = false
}

variable "ssm_namespace" {
  description = "Segmento de la ruta SSM (evita colisiones si hay más de una base de datos en el entorno)."
  type        = string
  default     = "aurora"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.ssm_namespace))
    error_message = "ssm_namespace debe ser minúsculas, dígitos y guiones (2-31 caracteres)."
  }

  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
