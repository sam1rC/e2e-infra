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

variable "domain_name" {
  description = "Dominio principal del certificado (p. ej. app.cliente.com)."
  type        = string

  validation {
    condition     = can(regex("^(\\*\\.)?([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name debe ser un nombre DNS válido en minúsculas (admite el comodín *. al inicio)."
  }

  nullable = false
}

variable "subject_alternative_names" {
  description = "Nombres alternativos adicionales (no repitas domain_name)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for d in var.subject_alternative_names : can(regex("^(\\*\\.)?([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", d))]) && !contains(var.subject_alternative_names, var.domain_name)
    error_message = "Los nombres alternativos deben ser DNS válidos y distintos de domain_name."
  }

  nullable = false
}

variable "key_algorithm" {
  description = "Algoritmo de la clave del certificado. RSA_2048 es el más compatible; EC_prime256v1 es más ligero y lo admiten CloudFront y ALB."
  type        = string
  default     = "RSA_2048"

  validation {
    condition     = contains(["RSA_2048", "EC_prime256v1", "EC_secp384r1"], var.key_algorithm)
    error_message = "key_algorithm debe ser RSA_2048, EC_prime256v1 o EC_secp384r1."
  }

  nullable = false
}

variable "zone_id" {
  description = "ID de la zona alojada de Route 53 donde crear los registros de validación. Si es null, el módulo no crea registros: los emite en validation_records para crearlos a mano."
  type        = string
  default     = null
}

variable "wait_for_validation" {
  description = "Espera a que el certificado esté emitido. Con zone_id se espera siempre; con DNS externo actívalo en un segundo apply, cuando los registros de validation_records ya existan (si no, el apply se bloquearía)."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
