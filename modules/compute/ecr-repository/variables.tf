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
  description = "Nombre de la aplicación/imagen; el repositorio se llama <project>-<environment>-<name>."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,40}[a-z0-9])?$", var.name))
    error_message = "name debe tener 1-42 caracteres: minúsculas, dígitos y guiones, sin guion al principio ni al final."
  }

  nullable = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK que cifra las imágenes del repositorio (obligatorio: no se usa el cifrado AES256 por defecto)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "scan_type" {
  description = "Escaneo de vulnerabilidades: basic (escaneo básico al subir la imagen) o enhanced (Amazon Inspector, continuo; requiere Inspector v2 para ECR, que activa account-baseline)."
  type        = string
  default     = "basic"

  validation {
    condition     = contains(["basic", "enhanced"], var.scan_type)
    error_message = "scan_type debe ser basic o enhanced."
  }

  nullable = false
}

variable "manage_registry_scanning" {
  description = "Crea la configuración de escaneo del REGISTRO (enhanced, continuo, para los repositorios <project>-<environment>-*). Es un recurso único por cuenta y región: actívalo en una sola instancia del módulo. Solo aplica con scan_type = enhanced."
  type        = bool
  default     = false
  nullable    = false
}

variable "keep_last_images" {
  description = "Número de imágenes a conservar; las más antiguas se expiran."
  type        = number
  default     = 30

  validation {
    condition     = var.keep_last_images >= 1 && var.keep_last_images <= 1000
    error_message = "keep_last_images debe estar entre 1 y 1000."
  }

  nullable = false
}

variable "untagged_expiry_days" {
  description = "Días tras los que se borran las imágenes sin etiqueta."
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_expiry_days >= 1 && var.untagged_expiry_days <= 365
    error_message = "untagged_expiry_days debe estar entre 1 y 365."
  }

  nullable = false
}

variable "ci_principal_arns" {
  description = "ARNs de roles IAM (p. ej. el rol de CI de otra cuenta) que pueden subir y descargar imágenes. Vacío = sin política de repositorio (solo la cuenta propietaria, por IAM)."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for a in var.ci_principal_arns : can(regex("^arn:[a-z-]+:iam::[0-9]{12}:role/", a))])
    error_message = "ci_principal_arns debe contener ARNs de roles IAM (arn:aws:iam::<cuenta>:role/...), nunca la raíz de una cuenta ni usuarios."
  }
}

variable "pull_principal_arns" {
  description = "ARNs de roles IAM que solo pueden descargar imágenes (p. ej. roles de ejecución de ECS de otras cuentas)."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for a in var.pull_principal_arns : can(regex("^arn:[a-z-]+:iam::[0-9]{12}:role/", a))])
    error_message = "pull_principal_arns debe contener ARNs de roles IAM (arn:aws:iam::<cuenta>:role/...)."
  }
}

variable "force_delete" {
  description = "Permite borrar el repositorio aunque contenga imágenes. Solo para entornos efímeros: por defecto false."
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
