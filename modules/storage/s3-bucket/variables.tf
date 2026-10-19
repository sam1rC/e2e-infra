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

variable "purpose" {
  description = "Propósito del bucket; forma parte del nombre y condiciona las políticas."
  type        = string

  validation {
    condition     = contains(["state", "logs", "data", "static-site", "backups"], var.purpose)
    error_message = "purpose debe ser uno de: state, logs, data, static-site, backups."
  }

  nullable = false
}

variable "bucket_name" {
  description = "Nombre exacto del bucket. Si es null: <project>-<environment>-<purpose>-<account_id>."
  type        = string
  default     = null

  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name debe tener 3-63 caracteres: minúsculas, dígitos, puntos y guiones."
  }
}

variable "sse_algorithm" {
  description = "Cifrado en reposo: aws:kms (CMK, por defecto) o AES256 (SSE-S3). AES256 solo donde el servicio escritor no admite KMS (logs de ALB/CloudFront estándar)."
  type        = string
  default     = "aws:kms"

  validation {
    condition     = contains(["aws:kms", "AES256"], var.sse_algorithm)
    error_message = "sse_algorithm debe ser aws:kms o AES256."
  }

  nullable = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK con la que se cifra el bucket. Obligatorio si sse_algorithm = aws:kms."
  type        = string
  default     = null

  validation {
    condition     = var.sse_algorithm != "aws:kms" || var.kms_key_arn != null
    error_message = "kms_key_arn es obligatorio cuando sse_algorithm = aws:kms."
  }
}

variable "force_destroy" {
  description = "Permite borrar el bucket aunque contenga objetos. Solo para entornos efímeros."
  type        = bool
  default     = false
  nullable    = false
}

variable "object_lock" {
  description = "Object Lock con retención por defecto (null = desactivado). Solo se puede activar al crear el bucket."
  type = object({
    mode = optional(string, "GOVERNANCE")
    days = number
  })
  default = null

  validation {
    condition     = var.object_lock == null || contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock.mode)
    error_message = "object_lock.mode debe ser GOVERNANCE o COMPLIANCE."
  }

  validation {
    condition     = var.object_lock == null || var.object_lock.days >= 1
    error_message = "object_lock.days debe ser >= 1."
  }
}

variable "lifecycle_config" {
  description = "Ciclo de vida del bucket. Los campos null desactivan esa acción. La limpieza de multipart incompletos y de versiones no actuales está activa por defecto."
  type = object({
    transition_to_ia_days           = optional(number)
    transition_to_glacier_days      = optional(number)
    expiration_days                 = optional(number)
    noncurrent_expiration_days      = optional(number, 90)
    noncurrent_versions_to_keep     = optional(number)
    abort_incomplete_multipart_days = optional(number, 7)
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      var.lifecycle_config.transition_to_ia_days == null ||
      var.lifecycle_config.transition_to_glacier_days == null ||
      var.lifecycle_config.transition_to_glacier_days > var.lifecycle_config.transition_to_ia_days
    )
    error_message = "transition_to_glacier_days debe ser mayor que transition_to_ia_days."
  }

  validation {
    condition     = var.lifecycle_config.transition_to_ia_days == null || var.lifecycle_config.transition_to_ia_days >= 30
    error_message = "S3 exige un mínimo de 30 días para la transición a STANDARD_IA."
  }
}

variable "access_logging" {
  description = "Logging de acceso al bucket (null = desactivado). El bucket destino debe permitir la entrega de logs de S3."
  type = object({
    target_bucket = string
    target_prefix = optional(string)
  })
  default = null
}

variable "deny_unencrypted_uploads" {
  description = "Añade una declaración que deniega PutObject con una cabecera de cifrado distinta a la configurada (las subidas sin cabecera siguen cifrándose por defecto)."
  type        = bool
  default     = false
  nullable    = false
}

variable "policy_statements" {
  description = "Declaraciones adicionales de la política del bucket. resource_paths son sufijos sobre el ARN del bucket: \"\" = el bucket, \"/*\" = todos los objetos, \"/prefijo/*\" = un prefijo."
  type = list(object({
    sid            = string
    effect         = optional(string, "Allow")
    actions        = list(string)
    resource_paths = optional(list(string), ["", "/*"])
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default  = []
  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales del bucket."
  type        = map(string)
  default     = {}
  nullable    = false
}
