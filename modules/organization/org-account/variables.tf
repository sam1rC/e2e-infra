variable "project" {
  description = "Nombre del proyecto; prefijo del nombre de la cuenta si name es null."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project debe ser minúsculas, dígitos y guiones (2-21 caracteres), empezando por letra."
  }

  nullable = false
}

variable "environment" {
  description = "Entorno al que pertenece la cuenta (las cuentas compartidas como security o log-archive usan prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "account_key" {
  description = "Identificador corto y estable de la cuenta (security, log-archive, app-prod, silo-<tenant>...). Forma el nombre <project>-<account_key> si name es null."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.account_key))
    error_message = "account_key debe ser minúsculas, dígitos y guiones (2-31 caracteres), empezando por letra."
  }

  nullable = false
}

variable "name" {
  description = "Nombre visible de la cuenta. null = <project>-<account_key>."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || (length(coalesce(var.name, "x")) >= 1 && length(coalesce(var.name, "x")) <= 50)
    error_message = "name debe tener entre 1 y 50 caracteres."
  }
}

variable "email" {
  description = "Correo raíz de la cuenta: único en AWS, de un buzón o alias del cliente que alguien lea (recuperación del usuario raíz). Cambiarlo después no se puede hacer desde OpenTofu."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.email)) && length(var.email) <= 64
    error_message = "email debe ser una dirección válida de como máximo 64 caracteres."
  }

  nullable = false
}

variable "parent_id" {
  description = "OU (ou-...) o raíz (r-...) donde se coloca la cuenta. Las SCP de org-guardrails se heredan de ahí."
  type        = string

  validation {
    condition     = can(regex("^(r-[0-9a-z]{4,32}|ou-[0-9a-z]{4,32}-[0-9a-z]{8,32})$", var.parent_id))
    error_message = "parent_id debe ser el ID de una OU (ou-...) o de la raíz (r-...)."
  }

  nullable = false
}

variable "role_name" {
  description = "Rol que Organizations crea en la cuenta nueva con AdministratorAccess y confianza en la cuenta de management. Solo para el bootstrap (account-baseline, cross-account-role); después se restringe con SCP y se usa IAM Identity Center."
  type        = string
  default     = "OrganizationAccountAccessRole"

  validation {
    condition     = can(regex("^[\\w+=,.@-]{1,64}$", var.role_name))
    error_message = "role_name debe ser un nombre de rol IAM válido."
  }

  nullable = false
}

variable "iam_user_access_to_billing" {
  description = "Permite a usuarios IAM de la cuenta ver la facturación (ALLOW) o no (DENY, por defecto: la facturación se consulta desde la cuenta de management)."
  type        = string
  default     = "DENY"

  validation {
    condition     = contains(["ALLOW", "DENY"], var.iam_user_access_to_billing)
    error_message = "iam_user_access_to_billing debe ser ALLOW o DENY."
  }

  nullable = false
}

variable "close_on_deletion" {
  description = "Cierra la cuenta al destruir el recurso. false (por defecto) solo la saca de OpenTofu: cerrar una cuenta borra todo lo que contiene tras 90 días y no se puede deshacer en ese plazo sin soporte."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales de la cuenta (p. ej. Tenant para cuentas silo)."
  type        = map(string)
  default     = {}
  nullable    = false
}
