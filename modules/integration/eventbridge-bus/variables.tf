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
  description = "Nombre del bus. Si es null: <project>-<environment>-events."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-z][a-z0-9-]{1,36}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-37 caracteres), empezando por letra."
  }
}

variable "kms_key_arn" {
  description = "ARN de la CMK que cifra el bus, el archivo y las colas DLQ. Su política debe autorizar a events.amazonaws.com (service_principals de foundation/kms-key) y, para las DLQ, a sqs.amazonaws.com."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "archive_retention_days" {
  description = "Días que el archivo conserva los eventos para poder reproducirlos (replay). 0 desactiva el archivo."
  type        = number
  default     = 30

  validation {
    condition     = var.archive_retention_days >= 0 && var.archive_retention_days <= 3650
    error_message = "archive_retention_days debe estar entre 0 (sin archivo) y 3650."
  }

  validation {
    condition     = var.environment != "prod" || var.archive_retention_days >= 7
    error_message = "En prod el archivo debe conservar al menos 7 días (necesario para reproducir eventos tras un incidente)."
  }

  nullable = false
}

variable "rules" {
  description = "Reglas del bus por clave estable (p. ej. orders, usage), cada una hacia un delivery stream de Data Firehose (S3 no es destino directo de EventBridge). El patrón se indica con source_prefixes y/o detail_type_prefixes (p. ej. [\"orders.\"]) o con event_pattern (JSON); no ambos. Cada regla tiene su DLQ SQS cifrada."
  type = map(object({
    firehose_arn         = string
    description          = optional(string, "")
    source_prefixes      = optional(list(string), [])
    detail_type_prefixes = optional(list(string), [])
    event_pattern        = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.rules) : can(regex("^[a-z][a-z0-9-]{0,19}$", k))])
    error_message = "Las claves de rules deben ser minúsculas, dígitos y guiones (1-20 caracteres), empezando por letra."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : can(regex("^arn:[a-z-]+:firehose:[a-z0-9-]+:[0-9]{12}:deliverystream/[a-zA-Z0-9_.-]+$", r.firehose_arn))])
    error_message = "firehose_arn debe ser el ARN de un delivery stream de Data Firehose."
  }

  validation {
    condition = alltrue([
      for r in values(var.rules) :
      (r.event_pattern != null) != (length(r.source_prefixes) + length(r.detail_type_prefixes) > 0)
    ])
    error_message = "Cada regla necesita source_prefixes/detail_type_prefixes o event_pattern, y no ambos."
  }

  validation {
    condition     = alltrue([for r in values(var.rules) : r.event_pattern == null || can(jsondecode(r.event_pattern))])
    error_message = "event_pattern debe ser JSON válido."
  }
}

variable "retry_policy" {
  description = "Reintentos de entrega a Firehose antes de enviar el evento a la DLQ."
  type = object({
    maximum_retry_attempts       = optional(number, 20)
    maximum_event_age_in_seconds = optional(number, 3600)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.retry_policy.maximum_retry_attempts >= 0 && var.retry_policy.maximum_retry_attempts <= 185
    error_message = "maximum_retry_attempts debe estar entre 0 y 185."
  }

  validation {
    condition     = var.retry_policy.maximum_event_age_in_seconds >= 60 && var.retry_policy.maximum_event_age_in_seconds <= 86400
    error_message = "maximum_event_age_in_seconds debe estar entre 60 y 86400."
  }
}

variable "dlq_retention_days" {
  description = "Días que las DLQ conservan los eventos no entregados (1-14)."
  type        = number
  default     = 14

  validation {
    condition     = var.dlq_retention_days >= 1 && var.dlq_retention_days <= 14
    error_message = "dlq_retention_days debe estar entre 1 y 14."
  }

  nullable = false
}

variable "target_kms_key_arns" {
  description = "CMK de los delivery streams destino, si cifran con clave propia: el rol de EventBridge recibe kms:GenerateDataKey sobre ellas, con kms:ViaService de Firehose."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "publisher_account_ids" {
  description = "Cuentas AWS adicionales autorizadas a publicar en el bus (events:PutEvents), p. ej. cuentas de aplicación. Vacío = solo la propia cuenta."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for a in var.publisher_account_ids : can(regex("^[0-9]{12}$", a))])
    error_message = "Cada cuenta debe ser un ID de 12 dígitos."
  }
}

variable "publish_ssm_parameters" {
  description = "Publica el nombre y el ARN del bus en SSM Parameter Store bajo /<project>/<env>/integration/ para las capas consumidoras."
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
