# Variables comunes de todas las raíces de live/ (valores en el *.auto.tfvars del directorio).

variable "account_id" {
  description = "Cuenta AWS donde se aplica esta raíz (allowed_account_ids del provider)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id debe tener 12 dígitos."
  }

  nullable = false
}

variable "region" {
  description = "Región principal de la cuenta."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.region))
    error_message = "region debe ser un código de región de AWS (p. ej. us-east-1)."
  }

  nullable = false
}

variable "assume_role_arn" {
  description = "Rol que asume el provider (p. ej. OrganizationAccountAccessRole al aplicar desde la cuenta de management). null = usar las credenciales del entorno (OIDC en CI, Identity Center en local)."
  type        = string
  default     = null
}

variable "project" {
  description = "Prefijo de nombres del cliente (minúsculas, dígitos y guiones)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project debe ser minúsculas, dígitos y guiones (2-21 caracteres), empezando por letra."
  }

  nullable = false
}

variable "environment" {
  description = "Entorno (dev, staging o prod); también decide la clave del estado y los valores por defecto de las capas."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "blueprint" {
  description = "Blueprint del catálogo desplegado (etiqueta Blueprint)."
  type        = string
  nullable    = false
}

variable "owner" {
  description = "Equipo responsable (etiqueta Owner)."
  type        = string
  nullable    = false
}

variable "cost_center" {
  description = "Centro de coste (etiqueta CostCenter)."
  type        = string
  nullable    = false
}

variable "data_classification" {
  description = "Clasificación de los datos (etiqueta DataClassification)."
  type        = string

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification debe ser public, internal, confidential o restricted."
  }

  nullable = false
}

variable "tenant" {
  description = "Tenant dueño de todos los recursos de esta raíz (etiqueta Tenant, solo en cuentas silo). null = sin etiqueta."
  type        = string
  default     = null
}

variable "extra_tags" {
  description = "Etiquetas adicionales del cliente (no pueden sustituir a las obligatorias)."
  type        = map(string)
  default     = {}
  nullable    = false
}

# Variables propias de la capa saas-t3/stack (mismo nombre, tipo y descripción que en el blueprint).
# Las opcionales valen null: la capa aplica su valor por defecto (nullable = false).

variable "domain_name" {
  description = "Dominio público de la aplicación SaaS (p. ej. app.cliente.com): alias de CloudFront, certificado y URLs de Cognito."
  type        = string
}

variable "zone_id" {
  description = "Zona de Route 53 del dominio: valida el certificado y crea los alias A/AAAA hacia CloudFront. null = DNS externo (entonces viewer_certificate_arn es obligatorio y los registros se crean a mano)."
  type        = string
  default     = null # null = valor por defecto de la capa
}

variable "viewer_certificate_arn" {
  description = "Certificado ACM ya emitido en us-east-1 que cubre domain_name (DNS fuera de Route 53, runbook external-dns-validation). null = el blueprint lo crea y valida en zone_id."
  type        = string
  default     = null # null = valor por defecto de la capa
}

variable "waf_mode" {
  description = "web_acl crea el Web ACL de CloudFront con edge/waf-web-acl; flat_rate no lo crea porque el WAF viene en el plan de precio fijo de CloudFront, que se contrata en la consola (paso manual del runbook)."
  type        = string
  default     = null # null = valor por defecto de la capa
}

variable "waf_rules_mode" {
  description = "Acción de las reglas gestionadas de los WAF: block o count. null = count en dev (para probar reglas nuevas) y block en el resto (plan 9.2)."
  type        = string
  default     = null # null = valor por defecto de la capa
}

variable "content_security_policy" {
  description = "Content-Security-Policy del sitio (depende del frontend). null = sin la cabecera."
  type        = string
  default     = null # null = valor por defecto de la capa
}

variable "spa_error_codes" {
  description = "Errores del origen que se sirven como /index.html (enrutado de la SPA). Afecta también a /api/*: un 403/404 de la API llega como index.html. Lista vacía para desactivarlo."
  type        = list(number)
  default     = null # null = valor por defecto de la capa
}

variable "price_class" {
  description = "Clase de precio de CloudFront."
  type        = string
  default     = null # null = valor por defecto de la capa
}

variable "usage_plans" {
  description = "Planes de uso de la REST API por tier (throttling y cuota por API key). El onboarding crea la API key de cada tenant y la asocia al plan de su tier (usage_plan_id/<tier> en SSM)."
  type = map(object({
    rate_limit   = number
    burst_limit  = number
    quota_limit  = optional(number)
    quota_period = optional(string, "MONTH")
  }))
  default = null # null = valor por defecto de la capa
}

variable "auth" {
  description = "Cognito compartido de tenants: callback_urls/logout_urls del app client web (vacías = https://<domain_name>/auth/callback y https://<domain_name>/), domain_prefix de managed login (null = sin dominio) y email (en prod, SES con sending_account = DEVELOPER). El alta de usuarios la hace el onboarding (custom:tenant_id), no hay registro libre."
  type = object({
    callback_urls = optional(list(string), [])
    logout_urls   = optional(list(string), [])
    domain_prefix = optional(string)
    email = optional(object({
      sending_account    = optional(string, "COGNITO_DEFAULT")
      source_arn         = optional(string)
      from_email_address = optional(string)
      reply_to           = optional(string)
    }), {})
  })
  default = null # null = valor por defecto de la capa
}

variable "manage_apigw_account_logging_role" {
  description = "Crea el rol de CloudWatch de API Gateway y lo fija en la cuenta/región (necesario para los logs de la REST API). Es único por cuenta y región: ponlo en false si otra pila de la cuenta ya lo gestiona."
  type        = bool
  default     = null # null = valor por defecto de la capa
}

variable "api_function" {
  description = "Código de la Lambda de la API (debe asumir el rol del tenant con la etiqueta de sesión del JWT y cachear las credenciales por tenant): paquete zip (s3_bucket + s3_key, con s3_object_version para fijarlo; runtime y handler) o imagen por digest (image_uri). Lo publica el pipeline de la aplicación."
  type = object({
    s3_bucket             = optional(string)
    s3_key                = optional(string)
    s3_object_version     = optional(string)
    runtime               = optional(string, "python3.13")
    handler               = optional(string, "app.handler")
    image_uri             = optional(string)
    memory_size           = optional(number, 512)
    timeout_seconds       = optional(number, 10)
    environment_variables = optional(map(string), {})
  })
}

variable "origin_verify_version" {
  description = "Versión del token x-origin-verify entre CloudFront y la API. Súbela para rotarlo: la Lambda acepta el valor actual y el anterior (AWSPREVIOUS) durante la propagación (ADR 0010)."
  type        = number
  default     = null # null = valor por defecto de la capa
}

variable "alarm_emails" {
  description = "Correos suscritos a las alarmas (deben confirmar la suscripción). En prod, al menos uno."
  type        = list(string)
  default     = null # null = valor por defecto de la capa
}
