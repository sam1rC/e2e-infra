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

variable "scope" {
  description = "Ámbito del Web ACL: CLOUDFRONT (instanciar con el provider de us-east-1) o REGIONAL (API Gateway REST, ALB...)."
  type        = string

  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "scope debe ser CLOUDFRONT o REGIONAL."
  }

  nullable = false
}

variable "create_web_acl" {
  description = "Crea el Web ACL. Ponlo en false cuando el WAF viene incluido en un plan flat-rate de CloudFront que se configura fuera de IaC (ver README)."
  type        = bool
  default     = true
  nullable    = false
}

variable "managed_rules_mode" {
  description = "block aplica las acciones de los grupos gestionados y de las reglas de tasa; count solo las registra (recomendado en dev para probar reglas nuevas antes de bloquear). La verificación de origen siempre bloquea."
  type        = string
  default     = "block"

  validation {
    condition     = contains(["block", "count"], var.managed_rules_mode)
    error_message = "managed_rules_mode debe ser block o count."
  }

  nullable = false
}

variable "count_size_restrictions_body" {
  description = "Deja SizeRestrictions_BODY de CommonRuleSet en modo count. Actívalo si los clientes suben archivos (el límite del cuerpo es de 8 KB)."
  type        = bool
  default     = false
  nullable    = false
}

variable "rate_limit_per_5m" {
  description = "Peticiones máximas por IP en 5 minutos antes de bloquear."
  type        = number
  default     = 2000

  validation {
    condition     = var.rate_limit_per_5m >= 10
    error_message = "rate_limit_per_5m debe ser al menos 10 (mínimo de WAF)."
  }

  nullable = false
}

variable "tenant_rate_limit" {
  description = "Segunda regla de tasa por cabecera de tenant (SaaS): limit peticiones en 5 minutos por valor de la cabecera. null = desactivada."
  type = object({
    header_name = string
    limit       = number
  })
  default = null

  validation {
    condition     = var.tenant_rate_limit == null || (var.tenant_rate_limit.limit >= 10 && can(regex("^[a-z0-9-]{1,64}$", var.tenant_rate_limit.header_name)))
    error_message = "tenant_rate_limit.limit debe ser >= 10 y header_name minúsculas, dígitos y guiones."
  }
}

variable "enable_bot_control" {
  description = "Añade AWSManagedRulesBotControlRuleSet (nivel COMMON). Tiene coste adicional por petición: solo T1."
  type        = bool
  default     = false
  nullable    = false
}

variable "anti_ddos" {
  description = "Añade AWSManagedRulesAntiDDoSRuleSet con prioridad 1 (antes que el resto, como recomienda AWS). Tiene coste adicional por petición: T1 o clientes con riesgo de inundaciones HTTP. sensitivity_to_block (regla DDoSRequests) y challenge_sensitivity (ChallengeDDoSRequests) en LOW|MEDIUM|HIGH: bloqueo conservador y challenge silencioso más amplio por defecto. exempt_uri_regexes son las URIs que no pueden resolver un challenge (API JSON y estáticos); revísalas por cliente: solo DDoSRequests puede bloquearlas. null = desactivado."
  type = object({
    sensitivity_to_block  = optional(string, "LOW")
    challenge_enabled     = optional(bool, true)
    challenge_sensitivity = optional(string, "HIGH")
    exempt_uri_regexes    = optional(list(string), ["^/api/", "\\.(css|gif|ico|jpe?g|js|json|map|mp[34]|otf|pdf|png|svg|ttf|txt|webm|webp|woff2?|xml)$"])
  })
  default = null

  validation {
    condition = var.anti_ddos == null || (
      contains(["LOW", "MEDIUM", "HIGH"], var.anti_ddos.sensitivity_to_block) &&
      contains(["LOW", "MEDIUM", "HIGH"], var.anti_ddos.challenge_sensitivity) &&
      length(var.anti_ddos.exempt_uri_regexes) <= 5
    )
    error_message = "anti_ddos: sensibilidades LOW, MEDIUM o HIGH y como máximo 5 expresiones exentas."
  }
}

variable "anonymous_ip_list_mode" {
  description = "AWSManagedRulesAnonymousIpList (VPN, Tor, proveedores de hosting) con prioridad 15: off, count (solo registra; empieza aquí) o block. Ojo: HostingProviderIPList bloquea tráfico servidor a servidor, como los webhooks de la pasarela de pagos; exclúyelos antes de pasar a block."
  type        = string
  default     = "off"

  validation {
    condition     = contains(["off", "count", "block"], var.anonymous_ip_list_mode)
    error_message = "anonymous_ip_list_mode debe ser off, count o block."
  }

  nullable = false
}

variable "origin_verify" {
  description = "Bloquea las peticiones que no lleven la cabecera de verificación de origen con el valor esperado (REST API de SaaS T3 detrás de CloudFront). El secreto acaba en el estado (cifrado) y en la configuración del Web ACL: es un token de verificación, no una credencial de datos (ADR 0010)."
  type = object({
    header_name = optional(string, "x-origin-verify")
    secret      = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.origin_verify == null || var.scope == "REGIONAL"
    error_message = "origin_verify solo tiene sentido con scope = REGIONAL (se asocia al stage de API Gateway)."
  }
}

variable "log_retention_days" {
  description = "Retención de los logs del WAF en CloudWatch Logs."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days debe ser un valor admitido por CloudWatch Logs."
  }

  nullable = false
}

variable "log_kms_key_arn" {
  description = "CMK con la que se cifra el grupo de logs (debe autorizar a logs.<región>.amazonaws.com). null = cifrado por defecto de CloudWatch Logs."
  type        = string
  default     = null
}

variable "association_arns" {
  description = "Recursos regionales a asociar (nombre estable => ARN), p. ej. el stage de API Gateway. Solo con scope = REGIONAL."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = length(var.association_arns) == 0 || var.scope == "REGIONAL"
    error_message = "association_arns solo se admite con scope = REGIONAL (CloudFront asocia el Web ACL desde la distribución)."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
