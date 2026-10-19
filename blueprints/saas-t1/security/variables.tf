variable "project" {
  description = "Nombre del proyecto (cliente); prefijo de cuentas, OU y políticas."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project debe ser minúsculas, dígitos y guiones (2-21 caracteres), empezando por letra."
  }

  nullable = false
}

variable "root_id" {
  description = "ID de la raíz de la organización (r-...). La organización (y el acceso de confianza de GuardDuty, Security Hub, Config, Access Analyzer e Inspector) existe antes: Control Tower o un paso manual del runbook."
  type        = string

  validation {
    condition     = can(regex("^r-[0-9a-z]{4,32}$", var.root_id))
    error_message = "root_id debe tener el formato r-xxxx."
  }

  nullable = false
}

variable "accounts" {
  description = "Cuentas miembro por clave estable (security, log-archive, control-plane, app-nonprod, app-prod, silo-<tenant>): correo raíz único, OU (security, infrastructure, nonprod, prod o silo), entorno y tenant (solo silo). Las cuentas existentes de Control Tower se importan con `tofu import`, no se recrean."
  type = map(object({
    email       = string
    ou          = string
    environment = optional(string, "prod")
    tenant_id   = optional(string)
  }))
  nullable = false

  validation {
    condition     = alltrue([for a in values(var.accounts) : contains(["security", "infrastructure", "nonprod", "prod", "silo"], a.ou)])
    error_message = "ou debe ser security, infrastructure, nonprod, prod o silo."
  }

  validation {
    condition     = alltrue([for k, a in var.accounts : (a.ou == "silo") == (a.tenant_id != null)])
    error_message = "Las cuentas de la OU silo (y solo ellas) llevan tenant_id."
  }

  validation {
    condition     = contains(keys(var.accounts), "security") && contains(keys(var.accounts), "log-archive")
    error_message = "SaaS T1 separa funciones: declara al menos las cuentas security y log-archive (plan 9.3, A8)."
  }
}

variable "guardrails" {
  description = "SCP de org-guardrails: roles de administración exentos (Control Tower, bootstrap), regiones permitidas (incluye us-east-1 por CloudFront/ACM/WAF) y RCP opcional (requiere organization_id)."
  type = object({
    admin_role_arns          = list(string)
    allowed_regions          = list(string)
    enable_rcp               = optional(bool, false)
    organization_id          = optional(string)
    bootstrap_role_arns      = optional(list(string), [])
    protected_state_buckets  = optional(list(string), [])
    protected_state_kms_keys = optional(list(string), [])
  })
  nullable = false
}

variable "delegated_admins" {
  description = "Delega en la cuenta security la administración de GuardDuty, Security Hub, Config, IAM Access Analyzer e Inspector para toda la organización (cada servicio necesita el acceso de confianza de Organizations habilitado)."
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
