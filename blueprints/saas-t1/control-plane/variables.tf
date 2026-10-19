variable "project" {
  description = "Nombre del proyecto (cliente); prefijo de los nombres de recursos y de las rutas SSM."
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


variable "pool_strategy" {
  description = "Estrategia de identidad del SaaS Lens: per_tier (un user pool por tier, p. ej. basic/pro/premium) o per_tenant (un pool por tenant, para tenants con requisitos propios de MFA, federación o región)."
  type        = string
  default     = "per_tier"

  validation {
    condition     = contains(["per_tier", "per_tenant"], var.pool_strategy)
    error_message = "pool_strategy debe ser per_tier o per_tenant."
  }

  nullable = false
}

variable "pools" {
  description = "Claves de los user pools: tiers (per_tier) o IDs de tenant (per_tenant), minúsculas y dígitos (máx. 24). Quitar una clave borra su pool y sus usuarios (en prod lo impide deletion_protection)."
  type        = list(string)
  default     = ["basic", "pro", "premium"]
  nullable    = false

  validation {
    condition     = length(var.pools) >= 1 && alltrue([for p in var.pools : can(regex("^[a-z][a-z0-9-]{0,23}$", p))])
    error_message = "Cada clave debe ser minúsculas, dígitos y guiones (1-24 caracteres), empezando por letra."
  }
}

variable "auth" {
  description = "Configuración común de los user pools: callback_urls/logout_urls del app client web, feature_plan (PLUS en T1: threat protection) y email (en prod, SES con sending_account = DEVELOPER)."
  type = object({
    callback_urls = list(string)
    logout_urls   = optional(list(string), [])
    feature_plan  = optional(string, "PLUS")
    email = optional(object({
      sending_account    = optional(string, "COGNITO_DEFAULT")
      source_arn         = optional(string)
      from_email_address = optional(string)
      reply_to           = optional(string)
    }), {})
  })
  nullable = false
}

variable "onboarding_function" {
  description = "Código de la Lambda de onboarding (alta en el registro, usuarios con custom:tenant_id y disparo del pipeline de los tenants silo): paquete zip (s3_bucket + s3_key, runtime, handler) o image_uri por digest."
  type = object({
    s3_bucket         = optional(string)
    s3_key            = optional(string)
    s3_object_version = optional(string)
    runtime           = optional(string, "python3.13")
    handler           = optional(string, "app.handler")
    image_uri         = optional(string)
    timeout_seconds   = optional(number, 60)
  })
  nullable = false

  validation {
    condition     = (var.onboarding_function.image_uri == null) == (var.onboarding_function.s3_bucket != null && var.onboarding_function.s3_key != null)
    error_message = "onboarding_function necesita image_uri o bien s3_bucket + s3_key (no ambos)."
  }
}

variable "silo_pipeline" {
  description = "Pipeline que despliega la infraestructura de un tenant silo (GitHub Actions workflow_dispatch con una GitHub App, nunca un token personal): repositorio owner/repo y workflow. La clave privada de la App se guarda a mano en el secreto que crea esta capa. null = sin tenants silo."
  type = object({
    repository = string
    workflow   = string
  })
  default = null
}

variable "app_account_ids" {
  description = "Cuentas del app plane (app-nonprod, app-prod y silos) autorizadas a publicar eventos de uso (metering) en el bus del control plane."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "alarm_emails" {
  description = "Correos suscritos a las alarmas del control plane. En prod, al menos uno."
  type        = list(string)
  default     = []

  validation {
    condition     = var.environment != "prod" || length(var.alarm_emails) > 0
    error_message = "En prod indica al menos un correo en alarm_emails."
  }

  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
