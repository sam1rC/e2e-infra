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
  description = "Nombre del cluster. Si es null: <project>-<environment>."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,254}$", var.name))
    error_message = "name debe tener 1-255 caracteres: letras, dígitos, guiones y guiones bajos."
  }
}

variable "kms_key_arn" {
  description = "ARN de la CMK que cifra el log group de ECS Exec y, si se indica, el almacenamiento efímero de Fargate. La política de la clave debe autorizar a logs.<región>.amazonaws.com."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "container_insights" {
  description = "Container Insights del cluster: enhanced (métricas a nivel de tarea y contenedor), enabled o disabled (no admitido en prod)."
  type        = string
  default     = "enhanced"

  validation {
    condition     = contains(["enhanced", "enabled", "disabled"], var.container_insights)
    error_message = "container_insights debe ser enhanced, enabled o disabled."
  }

  validation {
    condition     = var.environment != "prod" || var.container_insights != "disabled"
    error_message = "En prod Container Insights no se puede desactivar (enhanced o enabled)."
  }

  nullable = false
}

variable "enable_exec" {
  description = "Configura ECS Exec con registro de sesiones cifrado (log group con CMK). null = true en dev/staging y false en prod. Los servicios deben activar enable_execute_command por su cuenta."
  type        = bool
  default     = null
}

variable "enable_fargate_spot" {
  description = "Añade FARGATE_SPOT como capacity provider. null = true en dev/staging y false en prod (las tareas Spot pueden interrumpirse con 2 minutos de aviso)."
  type        = bool
  default     = null
}

variable "fargate_spot_weight" {
  description = "Peso de FARGATE_SPOT frente a FARGATE (peso 1, base 1) en la estrategia por defecto, cuando Spot está activo."
  type        = number
  default     = 3

  validation {
    condition     = var.fargate_spot_weight >= 1 && var.fargate_spot_weight <= 1000
    error_message = "fargate_spot_weight debe estar entre 1 y 1000."
  }

  nullable = false
}

variable "ephemeral_storage_kms_key_arn" {
  description = "CMK para cifrar el almacenamiento efímero de las tareas Fargate (managed_storage_configuration). null = cifrado gestionado por AWS. La política de la clave debe autorizar a Fargate (ver la documentación de ECS)."
  type        = string
  default     = null

  validation {
    condition     = var.ephemeral_storage_kms_key_arn == null || can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.ephemeral_storage_kms_key_arn))
    error_message = "ephemeral_storage_kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }
}

variable "log_retention_days" {
  description = "Retención de los log groups de ECS Exec y de Container Insights, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90."
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

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
