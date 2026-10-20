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
  description = "Nombre lógico del stream; el real es <project>-<environment>-<name>."
  type        = string
  default     = "events"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-31 caracteres), empezando por letra."
  }

  nullable = false
}

variable "bucket_arn" {
  description = "ARN del bucket S3 de destino (p. ej. el módulo storage/s3-bucket con purpose = data), cifrado con SSE-KMS."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_arn))
    error_message = "bucket_arn debe ser el ARN de un bucket S3 (arn:aws:s3:::nombre)."
  }

  nullable = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK que cifra los objetos en S3, el stream y el log group. Su política debe autorizar a logs.<región>.amazonaws.com (service_principals de foundation/kms-key); el rol de Firehose recibe los permisos por su cuenta."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "buffer" {
  description = "Búfer antes de escribir un objeto en S3: interval_seconds (0-900) y size_mb (1-128). Un evento tarda como máximo interval_seconds en aparecer en S3. Con partición dinámica, size_mb debe ser al menos 64."
  type = object({
    interval_seconds = optional(number, 60)
    size_mb          = optional(number, 5)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.buffer.interval_seconds >= 0 && var.buffer.interval_seconds <= 900
    error_message = "buffer.interval_seconds debe estar entre 0 y 900."
  }

  validation {
    condition     = var.buffer.size_mb >= 1 && var.buffer.size_mb <= 128
    error_message = "buffer.size_mb debe estar entre 1 y 128."
  }

  validation {
    condition     = var.dynamic_partitioning == null || var.buffer.size_mb >= 64
    error_message = "Con partición dinámica, buffer.size_mb debe ser al menos 64."
  }
}

variable "compression_format" {
  description = "Compresión de los objetos: GZIP, ZIP, Snappy o HADOOP_SNAPPY."
  type        = string
  default     = "GZIP"

  validation {
    condition     = contains(["GZIP", "ZIP", "Snappy", "HADOOP_SNAPPY"], var.compression_format)
    error_message = "compression_format debe ser GZIP, ZIP, Snappy o HADOOP_SNAPPY."
  }

  nullable = false
}

variable "prefix" {
  description = "Prefijo base de los objetos (sin barra inicial; con barra final). Se le añade la partición por fecha !{timestamp:yyyy/MM/dd}/ y, con partición dinámica, la clave del tenant."
  type        = string
  default     = "events/"

  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]*/$", var.prefix)) && !startswith(var.prefix, "/")
    error_message = "prefix debe terminar en / y no empezar por /."
  }

  nullable = false
}

variable "error_prefix" {
  description = "Prefijo de los objetos que Firehose no puede entregar o procesar (sin barra inicial; con barra final). Se le añade el tipo de error y la fecha."
  type        = string
  default     = "errors/"

  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]*/$", var.error_prefix)) && !startswith(var.error_prefix, "/")
    error_message = "error_prefix debe terminar en / y no empezar por /."
  }

  nullable = false
}

variable "dynamic_partitioning" {
  description = "Partición dinámica por clave de cada evento (SaaS: un prefijo por tenant). key_name es el nombre de la partición y jq_query la expresión JQ sobre el evento de EventBridge (p. ej. .detail.tenant_id). Los eventos sin esa clave van al prefijo de errores. null = solo partición por fecha."
  type = object({
    key_name = string
    jq_query = string
  })
  default = null

  validation {
    condition     = var.dynamic_partitioning == null || can(regex("^[a-z][a-z0-9_]{0,30}$", var.dynamic_partitioning.key_name))
    error_message = "dynamic_partitioning.key_name debe ser minúsculas, dígitos y guiones bajos, empezando por letra."
  }

  validation {
    condition     = var.dynamic_partitioning == null || startswith(var.dynamic_partitioning.jq_query, ".")
    error_message = "dynamic_partitioning.jq_query debe ser una expresión JQ que empiece por . (p. ej. .detail.tenant_id)."
  }
}

variable "log_retention_days" {
  description = "Retención del log group de errores de entrega, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90."
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

variable "publish_ssm_parameters" {
  description = "Publica el nombre y el ARN del stream en SSM Parameter Store bajo /<project>/<env>/integration/ para las capas consumidoras."
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
