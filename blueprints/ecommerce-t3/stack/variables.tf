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
  description = "Dominio público de la tienda (p. ej. tienda.cliente.com): alias de CloudFront, certificado y URLs de Cognito."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name debe ser un nombre DNS válido en minúsculas."
  }

  nullable = false
}

variable "zone_id" {
  description = "Zona de Route 53 del dominio: valida el certificado y crea los alias A/AAAA hacia CloudFront. null = DNS externo (entonces viewer_certificate_arn es obligatorio y los registros se crean a mano)."
  type        = string
  default     = null
}

variable "viewer_certificate_arn" {
  description = "Certificado ACM ya emitido en us-east-1 que cubre domain_name (DNS fuera de Route 53, runbook external-dns-validation). null = el blueprint lo crea y valida en zone_id."
  type        = string
  default     = null

  validation {
    condition     = var.viewer_certificate_arn != null || var.zone_id != null
    error_message = "Indica zone_id (el blueprint emite el certificado) o viewer_certificate_arn (certificado emitido fuera)."
  }

  validation {
    condition     = var.viewer_certificate_arn == null || can(regex("^arn:[a-z-]+:acm:us-east-1:[0-9]{12}:certificate/", var.viewer_certificate_arn))
    error_message = "viewer_certificate_arn debe ser un certificado de ACM en us-east-1."
  }
}

variable "waf_mode" {
  description = "web_acl crea el Web ACL de CloudFront con edge/waf-web-acl; flat_rate no lo crea porque el WAF viene en el plan de precio fijo de CloudFront, que se contrata en la consola (paso manual del runbook)."
  type        = string
  default     = "web_acl"

  validation {
    condition     = contains(["web_acl", "flat_rate"], var.waf_mode)
    error_message = "waf_mode debe ser web_acl o flat_rate."
  }

  nullable = false
}

variable "waf_rules_mode" {
  description = "Acción de las reglas gestionadas de los WAF: block o count. null = count en dev (para probar reglas nuevas) y block en el resto (plan 9.2)."
  type        = string
  default     = null

  validation {
    condition     = var.waf_rules_mode == null || contains(["block", "count"], coalesce(var.waf_rules_mode, "block"))
    error_message = "waf_rules_mode debe ser block o count."
  }
}

variable "content_security_policy" {
  description = "Content-Security-Policy del sitio (depende del frontend). null = sin la cabecera."
  type        = string
  default     = null
}

variable "spa_error_codes" {
  description = "Errores que se sirven como /index.html con 200. Desaconsejado (por defecto ninguno): el enrutado de la SPA lo hace una CloudFront Function, y esta reescritura convertiría en 200 los bloqueos del WAF y los 403/404 de /api/*."
  type        = list(number)
  default     = []
  nullable    = false
}

variable "price_class" {
  description = "Clase de precio de CloudFront."
  type        = string
  default     = "PriceClass_100"
  nullable    = false
}

variable "database" {
  description = "Base de datos de la tienda: dynamodb (por defecto, sin VPC) o aurora_data_api (Aurora Serverless v2 con RDS Data API en una VPC solo de datos; la Lambda sigue fuera de la VPC)."
  type        = string
  default     = "dynamodb"

  validation {
    condition     = contains(["dynamodb", "aurora_data_api"], var.database)
    error_message = "database debe ser dynamodb o aurora_data_api."
  }

  nullable = false
}

variable "aurora" {
  description = "Opción aurora_data_api: red solo de datos (vpc_cidr, az_names: 2 o 3 AZ explícitas), versión del motor y escalado. min_capacity null = 0 (auto-pausa) fuera de prod y 0.5 en prod."
  type = object({
    vpc_cidr       = optional(string, "10.40.0.0/20")
    az_names       = optional(list(string), [])
    engine_version = optional(string, "17.11")
    min_capacity   = optional(number)
    max_capacity   = optional(number, 4)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.database != "aurora_data_api" || length(var.aurora.az_names) >= 2
    error_message = "Con database = aurora_data_api indica aurora.az_names (2 o 3 AZ)."
  }
}

variable "api_function" {
  description = "Código de la Lambda de la API: paquete zip (s3_bucket + s3_key, con s3_object_version para fijarlo; runtime y handler) o imagen por digest (image_uri). Lo publica el pipeline de la aplicación."
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
  nullable = false

  validation {
    condition     = (var.api_function.image_uri == null) == (var.api_function.s3_bucket != null && var.api_function.s3_key != null)
    error_message = "api_function necesita image_uri o bien s3_bucket + s3_key (no ambos)."
  }
}

variable "api_routes" {
  description = "Rutas de la HTTP API (route key => autorización JWT o NONE y scopes). Todas llegan a la Lambda de la API por CloudFront en /api/*."
  type = map(object({
    authorization = optional(string, "JWT")
    scopes        = optional(list(string), [])
  }))
  default = {
    "ANY /api/{proxy+}" = {}
  }
  nullable = false
}

variable "auth" {
  description = "Cognito de clientes: callback_urls/logout_urls del app client web (vacías = https://<domain_name>/auth/callback y https://<domain_name>/), domain_prefix de managed login (null = sin dominio) y email (en prod, SES con sending_account = DEVELOPER)."
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
  default  = {}
  nullable = false
}

variable "origin_verify_version" {
  description = "Versión del token x-origin-verify entre CloudFront y la API. Súbela para rotarlo: la Lambda acepta el valor actual y el anterior (AWSPREVIOUS) durante la propagación (ADR 0010)."
  type        = number
  default     = 1

  validation {
    condition     = var.origin_verify_version >= 1 && floor(var.origin_verify_version) == var.origin_verify_version
    error_message = "origin_verify_version debe ser un entero mayor o igual que 1."
  }

  nullable = false
}

variable "alarm_emails" {
  description = "Correos suscritos a las alarmas (deben confirmar la suscripción). En prod, al menos uno."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
