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

variable "kms_admin_principal_arns" {
  description = "ARNs que administran la clave de estado (sin permiso de uso)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "kms_user_principal_arns" {
  description = "ARNs con permiso de uso explícito sobre la clave de estado. Los roles de CI no lo necesitan si su política IAM incluye kms:Decrypt/GenerateDataKey: la key policy delega en IAM."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "object_lock_days" {
  description = "Días de retención por defecto con Object Lock en modo GOVERNANCE (null = sin Object Lock). Solo se puede activar al crear el bucket."
  type        = number
  default     = null

  validation {
    condition     = var.object_lock_days == null || var.object_lock_days >= 1
    error_message = "object_lock_days debe ser >= 1 o null."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Días que se conservan las versiones anteriores del estado."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Conserva al menos 30 días de versiones del estado para poder recuperarte de un error."
  }

  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
