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
  description = "Nombre de la función; se llama <project>-<environment>-<name> (máx. 64 caracteres)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$", var.name))
    error_message = "name debe tener 1-32 caracteres: minúsculas, dígitos y guiones, sin guion al principio ni al final."
  }

  nullable = false
}

variable "runtime" {
  description = "Runtime de la función (paquete zip); null con image_uri. Solo runtimes vigentes (se excluyen los obsoletos); revisa la lista oficial de runtimes de Lambda al actualizar el módulo."
  type        = string
  default     = null

  validation {
    condition = var.runtime == null || contains([
      "python3.12", "python3.13", "python3.14",
      "nodejs22.x", "nodejs24.x",
      "java21", "java25",
      "dotnet8", "dotnet10",
      "ruby3.3", "ruby3.4",
      "provided.al2023",
    ], var.runtime)
    error_message = "runtime debe ser uno de los runtimes vigentes: python3.12/3.13/3.14, nodejs22.x/24.x, java21/25, dotnet8/10, ruby3.3/3.4 o provided.al2023."
  }
}

variable "handler" {
  description = "Handler de la función (paquete zip); null con image_uri."
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "Bucket con el paquete zip (el build es del pipeline de la aplicación). Usa s3_bucket + s3_key o image_uri, no ambos."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "Clave del paquete zip en s3_bucket."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Versión del objeto S3 del paquete (el bucket está versionado): fija exactamente el código desplegado."
  type        = string
  default     = null
}

variable "image_uri" {
  description = "Imagen de contenedor por DIGEST (<repo>@sha256:<64 hex>). Alternativa al paquete zip."
  type        = string
  default     = null

  validation {
    condition     = var.image_uri == null || can(regex("@sha256:[0-9a-f]{64}$", var.image_uri))
    error_message = "image_uri debe referenciarse por digest: <repositorio>@sha256:<64 caracteres hexadecimales>."
  }

  validation {
    condition = (
      (var.image_uri != null && var.s3_bucket == null && var.s3_key == null && var.runtime == null && var.handler == null) ||
      (var.image_uri == null && var.s3_bucket != null && var.s3_key != null && var.runtime != null && var.handler != null)
    )
    error_message = "Indica o bien image_uri (sin s3_bucket, s3_key, runtime ni handler), o bien s3_bucket + s3_key + runtime + handler."
  }
}

variable "architecture" {
  description = "Arquitectura de la función: arm64 (Graviton, por defecto) o x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture debe ser arm64 o x86_64."
  }

  nullable = false
}

variable "memory_size" {
  description = "Memoria en MB (128-10240)."
  type        = number
  default     = 256

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size debe estar entre 128 y 10240."
  }

  nullable = false
}

variable "timeout_seconds" {
  description = "Tiempo máximo de ejecución en segundos (1-900)."
  type        = number
  default     = 10

  validation {
    condition     = var.timeout_seconds >= 1 && var.timeout_seconds <= 900
    error_message = "timeout_seconds debe estar entre 1 y 900."
  }

  nullable = false
}

variable "environment_variables" {
  description = "Variables de entorno NO secretas (se cifran con kms_key_arn). Los secretos se leen en ejecución desde Secrets Manager con una política inyectada: nunca van aquí."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "kms_key_arn" {
  description = "CMK que cifra las variables de entorno, el log group y la cola DLQ. Su política debe autorizar a logs.<región>.amazonaws.com y, con DLQ, a SQS."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "log_retention_days" {
  description = "Retención del log group, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90."
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

variable "application_log_level" {
  description = "Nivel mínimo de los logs de la aplicación en formato JSON."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"], var.application_log_level)
    error_message = "application_log_level debe ser TRACE, DEBUG, INFO, WARN, ERROR o FATAL."
  }

  nullable = false
}

variable "system_log_level" {
  description = "Nivel mínimo de los logs del sistema de Lambda."
  type        = string
  default     = "WARN"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN"], var.system_log_level)
    error_message = "system_log_level debe ser DEBUG, INFO o WARN."
  }

  nullable = false
}

variable "policies" {
  description = "Políticas JSON en línea del rol de ejecución, por nombre estable, con acciones y recursos explícitos. El módulo solo añade lo imprescindible (logs, trazas, VPC, DLQ, KMS); nada más."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "permissions_boundary_arn" {
  description = "ARN de una permissions boundary para el rol de ejecución. null = ninguna."
  type        = string
  default     = null

  validation {
    condition     = var.permissions_boundary_arn == null || can(regex("^arn:[a-z-]+:iam::[0-9]{12}:policy/", var.permissions_boundary_arn))
    error_message = "permissions_boundary_arn debe ser el ARN de una política IAM."
  }
}

variable "vpc_config" {
  description = "Ejecuta la función dentro de la VPC (subredes app). El módulo crea un security group sin entrada y con la salida de egress_rules. null = sin VPC."
  type = object({
    vpc_id     = string
    subnet_ids = list(string)
    egress_rules = optional(map(object({
      description       = string
      port              = number
      protocol          = optional(string, "tcp")
      security_group_id = optional(string)
      prefix_list_id    = optional(string)
      cidr_ipv4         = optional(string)
    })), {})
  })
  default = null

  validation {
    condition     = var.vpc_config == null || (length(var.vpc_config.subnet_ids) >= 1 && can(regex("^vpc-[0-9a-f]+$", var.vpc_config.vpc_id)))
    error_message = "vpc_config necesita vpc_id (vpc-xxxxxxxx) y al menos una subred."
  }

  validation {
    condition = var.vpc_config == null || alltrue([
      for r in values(var.vpc_config.egress_rules) :
      length([for d in [r.security_group_id, r.prefix_list_id, r.cidr_ipv4] : d if d != null]) == 1
    ])
    error_message = "Cada regla de salida necesita exactamente un destino: security_group_id, prefix_list_id o cidr_ipv4."
  }

  validation {
    condition     = var.vpc_config == null || alltrue([for r in values(var.vpc_config.egress_rules) : r.port >= 1 && r.port <= 65535 && contains(["tcp", "udp"], r.protocol)])
    error_message = "Cada regla de salida necesita un puerto 1-65535 y protocolo tcp o udp."
  }
}

variable "reserved_concurrent_executions" {
  description = "Concurrencia reservada de la función (limita y garantiza su capacidad). null = sin reserva."
  type        = number
  default     = null

  validation {
    condition     = var.reserved_concurrent_executions == null || var.reserved_concurrent_executions >= 0
    error_message = "reserved_concurrent_executions no puede ser negativo (0 deshabilita la función)."
  }
}

variable "enable_dlq" {
  description = "Crea una cola SQS cifrada con la CMK como destino de las invocaciones asíncronas fallidas (dead-letter)."
  type        = bool
  default     = false
  nullable    = false
}

variable "dlq_retention_days" {
  description = "Días que la cola DLQ conserva los mensajes (1-14)."
  type        = number
  default     = 14

  validation {
    condition     = var.dlq_retention_days >= 1 && var.dlq_retention_days <= 14
    error_message = "dlq_retention_days debe estar entre 1 y 14."
  }

  nullable = false
}

variable "code_signing" {
  description = "Firma de código: perfiles de AWS Signer cuyos paquetes se aceptan (ARN de versión de perfil). Con policy Enforce, Lambda rechaza paquetes sin firma válida. Solo para paquetes zip. null = sin firma."
  type = object({
    signing_profile_version_arns = list(string)
    policy                       = optional(string, "Enforce")
  })
  default = null

  validation {
    condition     = var.code_signing == null || (length(var.code_signing.signing_profile_version_arns) >= 1 && contains(["Enforce", "Warn"], var.code_signing.policy))
    error_message = "code_signing necesita al menos un perfil de firma y policy Enforce o Warn."
  }

  validation {
    condition     = var.code_signing == null || var.image_uri == null
    error_message = "La firma de código solo se aplica a paquetes zip, no a imágenes de contenedor."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
