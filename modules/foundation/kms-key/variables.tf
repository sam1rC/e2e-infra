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
  description = "Propósito de la clave (state, data, logs, ...); forma parte del alias."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.purpose))
    error_message = "purpose debe ser minúsculas, dígitos y guiones (2-31 caracteres), empezando por letra."
  }

  nullable = false
}

variable "description" {
  description = "Descripción de la clave. Si es null se genera a partir de project/environment/purpose."
  type        = string
  default     = null
}

variable "multi_region" {
  description = "Crea una clave multi-región (solo si hay una réplica prevista, p. ej. copias de backup cross-region)."
  type        = bool
  default     = false
  nullable    = false
}

variable "deletion_window_in_days" {
  description = "Días de espera antes de borrar la clave definitivamente."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days debe estar entre 7 y 30."
  }

  nullable = false
}

variable "admin_principal_arns" {
  description = "ARNs de los principals que administran la clave (sin permiso de uso). Si es vacío, solo la raíz de la cuenta (que delega en IAM) puede administrarla."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "user_principal_arns" {
  description = "ARNs de los principals que pueden usar la clave (Encrypt/Decrypt/GenerateDataKey*/DescribeKey)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "service_principals" {
  description = "Servicios AWS (p. ej. s3.amazonaws.com, logs.<region>.amazonaws.com) que usan la clave directamente como principal de servicio. El acceso de principals de la cuenta vía servicio (kms:ViaService) se define con via_services."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "via_services" {
  description = "Servicios (p. ej. s3.us-east-1.amazonaws.com) a través de los cuales cualquier principal de la cuenta puede usar la clave (kms:ViaService + kms:CallerAccount)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "additional_policy_documents" {
  description = "Documentos de política JSON que se fusionan en la key policy, para declaraciones exactas que exige un servicio (p. ej. CloudTrail con aws:SourceArn y contexto de cifrado). Los Sid deben ser únicos y distintos de los del módulo."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales para la clave."
  type        = map(string)
  default     = {}
  nullable    = false
}
