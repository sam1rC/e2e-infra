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
  description = "Nombre lógico de la API; el nombre real es <project>-<environment>-<name>."
  type        = string
  default     = "api"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-31 caracteres), empezando por letra."
  }

  nullable = false
}

variable "integrations" {
  description = "Integraciones Lambda proxy (formato de payload 2.0) por clave estable: lambda_function_arn y timeout_milliseconds (50-30000; el máximo de HTTP API es 30 s). El módulo concede a esta API el permiso para invocar cada función."
  type = map(object({
    lambda_function_arn  = string
    timeout_milliseconds = optional(number, 29000)
  }))
  nullable = false

  validation {
    condition     = length(var.integrations) >= 1 && alltrue([for k in keys(var.integrations) : can(regex("^[a-z][a-z0-9-]{0,30}$", k))])
    error_message = "Declara al menos una integración; las claves deben ser minúsculas, dígitos y guiones."
  }

  validation {
    condition     = alltrue([for i in values(var.integrations) : can(regex("^arn:aws[a-z-]*:lambda:[a-z0-9-]+:[0-9]{12}:function:[A-Za-z0-9_-]+(:[A-Za-z0-9_$-]+)?$", i.lambda_function_arn))])
    error_message = "lambda_function_arn debe ser el ARN de una función Lambda (con alias opcional)."
  }

  validation {
    condition     = alltrue([for i in values(var.integrations) : i.timeout_milliseconds >= 50 && i.timeout_milliseconds <= 30000])
    error_message = "timeout_milliseconds debe estar entre 50 y 30000."
  }
}

variable "routes" {
  description = "Rutas por route key (\"GET /orders\", \"POST /orders/{id}\" o \"$default\"): integration (clave de integrations), authorization (JWT por defecto o NONE para rutas públicas, como un catálogo), scopes OAuth exigidos (solo con JWT; requieren access token) y límites de throttling propios de la ruta."
  type = map(object({
    integration            = string
    authorization          = optional(string, "JWT")
    scopes                 = optional(list(string), [])
    throttling_burst_limit = optional(number)
    throttling_rate_limit  = optional(number)
  }))
  nullable = false

  validation {
    condition     = length(var.routes) >= 1 && alltrue([for k in keys(var.routes) : can(regex("^(\\$default|(ANY|GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) /[A-Za-z0-9._~{}+/-]*)$", k))])
    error_message = "Las claves de routes deben ser route keys válidas: \"$default\" o \"<MÉTODO> /ruta\" (ANY, GET, POST, PUT, PATCH, DELETE, HEAD u OPTIONS)."
  }

  validation {
    condition     = alltrue([for r in values(var.routes) : contains(keys(var.integrations), r.integration)])
    error_message = "Cada ruta debe apuntar a una clave existente de integrations."
  }

  validation {
    condition     = alltrue([for r in values(var.routes) : contains(["JWT", "NONE"], r.authorization) && (r.authorization == "JWT" || length(r.scopes) == 0)])
    error_message = "authorization debe ser JWT o NONE, y las scopes solo se admiten con JWT."
  }

  validation {
    condition     = var.jwt_authorizer != null || alltrue([for r in values(var.routes) : r.authorization == "NONE"])
    error_message = "Las rutas con authorization = JWT necesitan jwt_authorizer."
  }
}

variable "jwt_authorizer" {
  description = "Autorizador JWT (Cognito u otro proveedor OIDC): issuer (p. ej. issuer_url de identity/cognito-user-pool) y audience (IDs de los app clients). Valida firma, emisor, audiencia y caducidad; NO valida claims personalizados como el tenant, que lee la aplicación."
  type = object({
    issuer   = string
    audience = list(string)
  })
  default = null

  validation {
    condition     = var.jwt_authorizer == null || (can(regex("^https://[^\\s]+$", var.jwt_authorizer.issuer)) && length(try(var.jwt_authorizer.audience, [])) >= 1)
    error_message = "jwt_authorizer.issuer debe ser una URL https:// y audience tener al menos un valor."
  }
}

variable "cors" {
  description = "CORS restringido a los orígenes del frontend (sin comodines). API Gateway responde a las peticiones preflight. null = sin CORS (la API solo se llama a través de CloudFront en el mismo dominio)."
  type = object({
    allow_origins     = list(string)
    allow_methods     = optional(list(string), ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
    allow_headers     = optional(list(string), ["authorization", "content-type"])
    expose_headers    = optional(list(string), [])
    max_age_seconds   = optional(number, 300)
    allow_credentials = optional(bool, false)
  })
  default = null

  validation {
    condition = var.cors == null || (
      length(try(var.cors.allow_origins, [])) >= 1 &&
      alltrue([for o in try(var.cors.allow_origins, []) : can(regex("^(https://[A-Za-z0-9.-]+(:[0-9]+)?|http://localhost(:[0-9]+)?)$", o))])
    )
    error_message = "cors.allow_origins debe listar orígenes exactos https:// (o http://localhost fuera de prod), sin comodines ni rutas."
  }

  validation {
    condition     = var.cors == null || var.environment != "prod" || alltrue([for o in try(var.cors.allow_origins, []) : startswith(o, "https://")])
    error_message = "En prod los orígenes CORS deben ser https://."
  }
}

variable "throttling" {
  description = "Límites por defecto de la API (todas las rutas): burst_limit (peticiones simultáneas) y rate_limit (peticiones por segundo). Las rutas pueden ajustarlos."
  type = object({
    burst_limit = optional(number, 100)
    rate_limit  = optional(number, 50)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.throttling.burst_limit >= 1 && var.throttling.rate_limit >= 1
    error_message = "throttling.burst_limit y rate_limit deben ser al menos 1."
  }
}

variable "disable_execute_api_endpoint" {
  description = "Desactiva el endpoint por defecto execute-api. Déjalo en false si el origen de CloudFront es ese endpoint (patrón de los blueprints T3); actívalo solo con un dominio propio de API Gateway."
  type        = bool
  default     = false
  nullable    = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK del entorno que cifra el log group de acceso. Su política debe autorizar al principal logs.<región>.amazonaws.com."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "log_retention_days" {
  description = "Retención del log group de acceso, en días. En prod, al menos 90."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days debe ser un valor admitido por CloudWatch Logs (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, ...)."
  }

  validation {
    condition     = var.environment != "prod" || var.log_retention_days >= 90
    error_message = "En prod la retención de logs debe ser de al menos 90 días."
  }

  nullable = false
}

variable "publish_ssm_parameters" {
  description = "Publica en SSM Parameter Store, bajo /<project>/<env>/api/<name>/, el ID y el endpoint de la API (origen de CloudFront en la capa de borde)."
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
