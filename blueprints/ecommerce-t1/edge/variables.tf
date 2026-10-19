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


variable "domain_name" {
  description = "Dominio público de la tienda (alias de CloudFront). Debe coincidir con el de la capa app, cuyo ALB lleva su certificado regional."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name debe ser un nombre DNS válido en minúsculas."
  }

  nullable = false
}

variable "zone_id" {
  description = "Zona de Route 53: valida el certificado del viewer y crea los alias A/AAAA. null = DNS externo (viewer_certificate_arn obligatorio)."
  type        = string
  default     = null
}

variable "viewer_certificate_arn" {
  description = "Certificado ACM emitido en us-east-1 para domain_name. null = el blueprint lo emite en zone_id."
  type        = string
  default     = null

  validation {
    condition     = var.viewer_certificate_arn != null || var.zone_id != null
    error_message = "Indica zone_id (el blueprint emite el certificado) o viewer_certificate_arn."
  }
}

variable "waf" {
  description = "Opciones del Web ACL de CloudFront: rules_mode (block o count; null = count en dev y block en el resto, plan 9.2), rate_limit_per_5m por IP, count_size_restrictions_body (subida de archivos), anonymous_ip_list_mode (off/count/block), bot_control y anti_ddos (AWSManagedRulesAntiDDoSRuleSet con los valores por defecto del módulo); estos dos tienen coste por petición."
  type = object({
    rules_mode                   = optional(string)
    rate_limit_per_5m            = optional(number, 2000)
    count_size_restrictions_body = optional(bool, false)
    anonymous_ip_list_mode       = optional(string, "off")
    bot_control                  = optional(bool, false)
    anti_ddos                    = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.waf.rules_mode == null || contains(["block", "count"], coalesce(var.waf.rules_mode, "block"))
    error_message = "waf.rules_mode debe ser block o count."
  }
}

variable "content_security_policy" {
  description = "Content-Security-Policy de la aplicación. null = sin la cabecera."
  type        = string
  default     = null
}

variable "static_path_patterns" {
  description = "Rutas servidas con caché (CachingOptimized); el resto va al ALB sin caché."
  type        = list(string)
  default     = ["/static/*", "/assets/*"]
  nullable    = false
}

variable "price_class" {
  description = "Clase de precio de CloudFront."
  type        = string
  default     = "PriceClass_100"
  nullable    = false
}

variable "alarm_emails" {
  description = "Correos del topic de alarmas de borde (us-east-1: las métricas de CloudFront y del WAF global solo existen allí). En prod, al menos uno."
  type        = list(string)
  default     = []

  validation {
    condition     = var.environment != "prod" || length(var.alarm_emails) > 0
    error_message = "En prod indica al menos un correo en alarm_emails: unas alarmas que nadie recibe no sirven."
  }

  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
