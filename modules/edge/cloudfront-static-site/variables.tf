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

variable "domain_names" {
  description = "Nombres de dominio públicos (alias) de la distribución. El certificado debe cubrirlos."
  type        = list(string)

  validation {
    condition     = length(var.domain_names) >= 1 && alltrue([for d in var.domain_names : can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", d))])
    error_message = "Indica al menos un dominio DNS válido en minúsculas."
  }

  nullable = false
}

variable "acm_certificate_arn" {
  description = "Certificado ACM del viewer (debe estar en us-east-1 y emitido)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:acm:us-east-1:[0-9]{12}:certificate/", var.acm_certificate_arn))
    error_message = "acm_certificate_arn debe ser un certificado de ACM en us-east-1."
  }

  nullable = false
}

variable "web_acl_arn" {
  description = "ARN del Web ACL de WAF (scope CLOUDFRONT). null con un plan flat-rate que lo incluye."
  type        = string
  default     = null

  validation {
    condition     = var.web_acl_arn == null || can(regex("^arn:[a-z-]+:wafv2:us-east-1:[0-9]{12}:global/webacl/", var.web_acl_arn))
    error_message = "web_acl_arn debe ser un Web ACL global (CLOUDFRONT) de us-east-1."
  }
}

variable "response_headers_policy_id" {
  description = "ID de la response headers policy de seguridad (módulo security-headers)."
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "CMK del bucket. Si es null el módulo crea una propia, con permiso de lectura para las distribuciones de CloudFront de la cuenta. Si aportas la tuya, su key policy debe permitir a cloudfront.amazonaws.com kms:Decrypt/GenerateDataKey* (con aws:SourceArn de la distribución)."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }
}

variable "force_destroy" {
  description = "Permite borrar el bucket aunque contenga objetos. Solo para entornos efímeros."
  type        = bool
  default     = false
  nullable    = false
}

variable "spa_error_codes" {
  description = "Códigos de error que se sirven como /index.html con 200 (aplicación de una sola página). Lista vacía para desactivarlo. OJO: es una configuración de toda la distribución y enmascara también los 403/404 del origen de API."
  type        = list(number)
  default     = [403, 404]

  validation {
    condition     = alltrue([for c in var.spa_error_codes : contains([400, 403, 404, 405, 414, 416, 500, 501, 502, 503, 504], c)])
    error_message = "spa_error_codes solo admite códigos de error que CloudFront puede reescribir (p. ej. 403 y 404)."
  }

  nullable = false
}

variable "api" {
  description = "Origen de API opcional (p. ej. API Gateway) que se sirve en path_pattern sin caché. domain_name es el dominio del endpoint, sin esquema."
  type = object({
    domain_name  = string
    origin_path  = optional(string, "")
    path_pattern = optional(string, "/api/*")
  })
  default = null

  validation {
    condition     = var.api == null || can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.api.domain_name))
    error_message = "api.domain_name debe ser un nombre DNS en minúsculas, sin esquema ni ruta."
  }

  validation {
    condition     = var.api == null || startswith(var.api.path_pattern, "/")
    error_message = "api.path_pattern debe empezar por /."
  }
}

variable "api_origin_verify_secret" {
  description = "Valor de la cabecera x-origin-verify que CloudFront añade al origen de API; el origen (WAF regional o middleware) bloquea lo que no la lleve, para que la API no se pueda llamar saltándose CloudFront/WAF. El secreto queda en el estado (cifrado) y es legible en la configuración de CloudFront: es un token de verificación rotable, no una credencial de datos (ADR 0010)."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.api_origin_verify_secret == null || var.api != null
    error_message = "api_origin_verify_secret solo tiene sentido si se define api."
  }

  validation {
    condition     = var.api_origin_verify_secret == null || length(var.api_origin_verify_secret) >= 32
    error_message = "El secreto de verificación debe tener al menos 32 caracteres."
  }
}

variable "price_class" {
  description = "Clase de precio de la distribución."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class debe ser PriceClass_100, PriceClass_200 o PriceClass_All."
  }

  nullable = false
}

variable "zone_id" {
  description = "Zona de Route 53 donde crear los registros A/AAAA (alias) hacia la distribución. null = el DNS se gestiona fuera."
  type        = string
  default     = null
}

variable "log_bucket_arn" {
  description = "Bucket S3 para los logs de acceso (logging estándar v2, sin ACL). La entrega escribe en AWSLogs/<cuenta>/CloudFront/<log_prefix>/...: su política debe permitir s3:PutObject en AWSLogs/<cuenta>/CloudFront/* a delivery.logs.amazonaws.com con aws:SourceAccount y aws:SourceArn del delivery source <project>-<environment>-cloudfront (si falta, CloudWatch Logs añade su propia declaración y el siguiente apply la borraría). null = sin logs."
  type        = string
  default     = null
}

variable "access_logs_enabled" {
  description = "Activa los logs de acceso. Indícalo (true) cuando log_bucket_arn se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crean los recursos de logging. null = activado si log_bucket_arn no es null."
  type        = bool
  default     = null

  validation {
    condition     = var.access_logs_enabled != true || var.log_bucket_arn != null
    error_message = "access_logs_enabled = true requiere log_bucket_arn."
  }
}

variable "log_prefix" {
  description = "Prefijo de los logs dentro del bucket."
  type        = string
  default     = "cloudfront"
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
