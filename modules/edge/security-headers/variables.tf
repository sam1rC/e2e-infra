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

variable "hsts_max_age_seconds" {
  description = "max-age de Strict-Transport-Security. 63072000 (2 años) es el valor exigido para entrar en la lista de preload."
  type        = number
  default     = 63072000

  validation {
    condition     = var.hsts_max_age_seconds >= 31536000
    error_message = "hsts_max_age_seconds debe ser al menos 31536000 (1 año) para poder usar preload."
  }

  nullable = false
}

variable "content_security_policy" {
  description = "Valor de Content-Security-Policy. Depende de la aplicación, por eso no hay valor por defecto: null no envía la cabecera."
  type        = string
  default     = null
}
