variable "project" {
  description = "Nombre del proyecto; prefijo del nombre del rol."
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
  description = "Nombre lógico del rol; el real es <project>-<environment>-<name> (p. ej. silo-deploy, provider-access)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-31 caracteres), empezando por letra."
  }

  nullable = false
}

variable "trusted_role_arns" {
  description = "Roles IAM de OTRAS cuentas que pueden asumir este rol (p. ej. el rol de apply de CI del control plane, o el rol de soporte del proveedor). Solo roles concretos: nunca la raíz de una cuenta, usuarios ni comodines."
  type        = list(string)

  validation {
    condition     = length(var.trusted_role_arns) >= 1 && alltrue([for a in var.trusted_role_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", a))])
    error_message = "trusted_role_arns debe contener al menos un ARN de rol IAM (arn:aws:iam::<cuenta>:role/<nombre>), sin comodines ni la raíz."
  }

  nullable = false
}

variable "external_id" {
  description = "ExternalId exigido en AssumeRole (sts:ExternalId): obligatorio cuando quien asume es un tercero (el proveedor) para evitar el confused deputy. No es un secreto, pero tampoco se publica. null = sin ExternalId (roles entre cuentas del propio cliente)."
  type        = string
  default     = null

  validation {
    condition     = var.external_id == null || (length(coalesce(var.external_id, "xx")) >= 2 && length(coalesce(var.external_id, "xx")) <= 1224 && can(regex("^[A-Za-z0-9+=,.@:/-]+$", coalesce(var.external_id, "xx"))))
    error_message = "external_id debe tener 2-1224 caracteres válidos para sts:ExternalId."
  }
}

variable "organization_id" {
  description = "Si se indica, solo pueden asumir el rol principals de esta organización (aws:PrincipalOrgID), además de estar en trusted_role_arns. Úsalo entre cuentas del cliente; nunca para el proveedor."
  type        = string
  default     = null

  validation {
    condition     = var.organization_id == null || can(regex("^o-[a-z0-9]{10,32}$", coalesce(var.organization_id, "o-0000000000")))
    error_message = "organization_id debe tener el formato o-xxxxxxxxxx."
  }
}

variable "require_mfa" {
  description = "Exige MFA en la sesión de quien asume el rol (aws:MultiFactorAuthPresent). Para accesos humanos (soporte del proveedor); no lo actives para roles de CI, que no tienen MFA."
  type        = bool
  default     = false
  nullable    = false
}

variable "allow_tag_session" {
  description = "Permite sts:TagSession (etiquetas de sesión para ABAC o trazabilidad en CloudTrail)."
  type        = bool
  default     = false
  nullable    = false
}

variable "max_session_duration" {
  description = "Duración máxima de la sesión, en segundos (3600-43200). 1 hora por defecto."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration debe estar entre 3600 y 43200."
  }

  nullable = false
}

variable "managed_policy_arns" {
  description = "Políticas gestionadas adjuntas, por clave estable (p. ej. readonly = arn:aws:iam::aws:policy/ReadOnlyAccess). Un mapa para que quitar una no afecte a las demás."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for a in values(var.managed_policy_arns) : can(regex("^arn:aws[a-z-]*:iam::([0-9]{12}|aws):policy/", a))])
    error_message = "Cada valor de managed_policy_arns debe ser el ARN de una política IAM."
  }
}

variable "inline_policies" {
  description = "Políticas JSON en línea, por nombre estable, con acciones y recursos explícitos."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = length(var.inline_policies) + length(var.managed_policy_arns) >= 1
    error_message = "El rol debe tener al menos una política (managed_policy_arns o inline_policies)."
  }

  validation {
    condition     = alltrue([for p in values(var.inline_policies) : can(jsondecode(p))])
    error_message = "Cada política en línea debe ser JSON válido."
  }
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary del rol: obligatoria si el rol puede crear o modificar roles IAM (p. ej. un rol de despliegue), para que no pueda escalar privilegios."
  type        = string
  default     = null

  validation {
    condition     = var.permissions_boundary_arn == null || can(regex("^arn:aws[a-z-]*:iam::([0-9]{12}|aws):policy/", coalesce(var.permissions_boundary_arn, "x")))
    error_message = "permissions_boundary_arn debe ser el ARN de una política IAM."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
