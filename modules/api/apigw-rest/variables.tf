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

variable "lambda_function_arn" {
  description = "ARN de la función Lambda que atiende la API (integración proxy en / y /{proxy+}; la función enruta por método y ruta). El módulo concede a esta etapa el permiso para invocarla."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:lambda:[a-z0-9-]+:[0-9]{12}:function:[A-Za-z0-9_-]+(:[A-Za-z0-9_$-]+)?$", var.lambda_function_arn))
    error_message = "lambda_function_arn debe ser el ARN de una función Lambda (con alias opcional)."
  }

  nullable = false
}

variable "integration_timeout_milliseconds" {
  description = "Timeout de la integración, en milisegundos (50-29000)."
  type        = number
  default     = 29000

  validation {
    condition     = var.integration_timeout_milliseconds >= 50 && var.integration_timeout_milliseconds <= 29000
    error_message = "integration_timeout_milliseconds debe estar entre 50 y 29000."
  }

  nullable = false
}

variable "cognito_user_pool_arns" {
  description = "ARNs de los user pools cuyos tokens acepta el autorizador COGNITO_USER_POOLS (uno por tier o por tenant en SaaS T1). Valida firma, emisor y caducidad del ID token (o del access token si hay authorization_scopes); no valida claims personalizados."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.cognito_user_pool_arns) >= 1 && alltrue([for a in var.cognito_user_pool_arns : can(regex("^arn:aws[a-z-]*:cognito-idp:[a-z0-9-]+:[0-9]{12}:userpool/[a-z0-9-]+_[A-Za-z0-9]+$", a))])
    error_message = "cognito_user_pool_arns debe contener al menos un ARN de user pool de Cognito."
  }
}

variable "authorization_scopes" {
  description = "Scopes OAuth exigidos en todos los métodos (salvo OPTIONS). Con scopes, el autorizador exige access tokens en lugar de ID tokens. Vacío = ID token."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "api_key_required" {
  description = "Exige API key (cabecera x-api-key) además del token: necesario para aplicar los planes de uso por tenant o tier. Las API keys las crea el onboarding de cada tenant (no OpenTofu) y las asocia al plan de su tier."
  type        = bool
  default     = true
  nullable    = false
}

variable "usage_plans" {
  description = "Planes de uso por tier (p. ej. basic, pro) con throttling (rate_limit por segundo, burst_limit) y cuota opcional (quota_limit peticiones por quota_period: DAY, WEEK o MONTH). Con api_key_required debe haber al menos uno."
  type = map(object({
    rate_limit   = number
    burst_limit  = number
    quota_limit  = optional(number)
    quota_period = optional(string, "MONTH")
    description  = optional(string, "")
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.usage_plans) : can(regex("^[a-z][a-z0-9-]{0,30}$", k))])
    error_message = "Las claves de usage_plans deben ser minúsculas, dígitos y guiones."
  }

  validation {
    condition = alltrue([
      for p in values(var.usage_plans) :
      p.rate_limit > 0 && p.burst_limit >= 1 && contains(["DAY", "WEEK", "MONTH"], p.quota_period) && (p.quota_limit == null || coalesce(p.quota_limit, 1) >= 1)
    ])
    error_message = "Cada plan necesita rate_limit > 0, burst_limit >= 1, quota_period DAY/WEEK/MONTH y quota_limit >= 1 si se indica."
  }

  validation {
    condition     = !var.api_key_required || length(var.usage_plans) >= 1
    error_message = "Con api_key_required = true declara al menos un plan de uso (sin plan, ninguna API key funciona)."
  }
}

variable "stage_name" {
  description = "Nombre de la etapa; es el origin_path del origen /api/* en CloudFront."
  type        = string
  default     = "v1"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,63}$", var.stage_name))
    error_message = "stage_name debe ser minúsculas, dígitos, guiones o guiones bajos, empezando por letra."
  }

  nullable = false
}

variable "throttling" {
  description = "Throttling de la etapa para todos los métodos (burst_limit, rate_limit por segundo). Los planes de uso limitan además por API key."
  type = object({
    burst_limit = optional(number, 100)
    rate_limit  = optional(number, 50)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.throttling.burst_limit >= 1 && var.throttling.rate_limit > 0
    error_message = "throttling.burst_limit debe ser >= 1 y rate_limit > 0."
  }
}

variable "cors_allow_origin" {
  description = "Origen exacto del frontend para CORS (https://app.ejemplo.com). Crea métodos OPTIONS sin autorización para el preflight y añade la cabecera a las respuestas de error de API Gateway; las respuestas de la Lambda deben incluir sus propias cabeceras CORS. null = sin CORS (llamadas a través de CloudFront en el mismo dominio)."
  type        = string
  default     = null

  validation {
    condition     = var.cors_allow_origin == null || can(regex("^(https://[A-Za-z0-9.-]+(:[0-9]+)?|http://localhost(:[0-9]+)?)$", var.cors_allow_origin))
    error_message = "cors_allow_origin debe ser un origen exacto https:// (o http://localhost fuera de prod), sin comodines ni rutas."
  }

  validation {
    condition     = var.cors_allow_origin == null || var.environment != "prod" || startswith(coalesce(var.cors_allow_origin, "https://"), "https://")
    error_message = "En prod el origen CORS debe ser https://."
  }
}

variable "minimum_compression_size" {
  description = "Tamaño mínimo de respuesta, en bytes, para comprimirla (0-10485760). null = sin compresión."
  type        = number
  default     = 1024

  validation {
    condition     = var.minimum_compression_size == null || (coalesce(var.minimum_compression_size, 0) >= 0 && coalesce(var.minimum_compression_size, 0) <= 10485760)
    error_message = "minimum_compression_size debe estar entre 0 y 10485760."
  }
}

variable "security_policy" {
  description = "Política TLS del endpoint execute-api. Las políticas SecurityPolicy_* (mejoradas) exigen endpoint_access_mode. Por defecto TLS 1.3 con 1.2 de respaldo."
  type        = string
  default     = "SecurityPolicy_TLS13_1_2_2021_06"

  validation {
    condition     = startswith(var.security_policy, "SecurityPolicy_TLS13_") || startswith(var.security_policy, "SecurityPolicy_TLS12_")
    error_message = "security_policy debe ser una política mejorada SecurityPolicy_TLS13_* o SecurityPolicy_TLS12_* (TLS >= 1.2)."
  }

  nullable = false
}

variable "endpoint_access_mode" {
  description = "STRICT (por defecto): API Gateway exige que el SNI y la cabecera Host coincidan con el endpoint (cierra el domain fronting); CloudFront cumple porque llega por el nombre execute-api. BASIC solo para migraciones. El cambio de BASIC a STRICT tarda unos 15 minutos en aplicarse."
  type        = string
  default     = "STRICT"

  validation {
    condition     = contains(["STRICT", "BASIC"], var.endpoint_access_mode)
    error_message = "endpoint_access_mode debe ser STRICT o BASIC."
  }

  nullable = false
}

variable "web_acl_arn" {
  description = "ARN de un Web ACL REGIONAL (edge/waf-web-acl con origin_verify) que se asocia a la etapa: bloquea las peticiones que no lleguen por CloudFront con la cabecera x-origin-verify. Obligatorio en prod."
  type        = string
  default     = null

  validation {
    condition     = var.web_acl_arn == null || can(regex("^arn:aws[a-z-]*:wafv2:[a-z0-9-]+:[0-9]{12}:regional/webacl/", var.web_acl_arn))
    error_message = "web_acl_arn debe ser el ARN de un Web ACL REGIONAL de WAFv2."
  }

  validation {
    condition     = var.environment != "prod" || var.web_acl_arn != null
    error_message = "En prod la etapa debe tener un Web ACL regional (verificación de origen y reglas gestionadas)."
  }
}

variable "web_acl_enabled" {
  description = "Asocia web_acl_arn a la etapa. Indícalo (true) cuando el Web ACL se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crea la asociación. null = asociar si web_acl_arn no es null."
  type        = bool
  default     = null

  validation {
    condition     = var.web_acl_enabled != true || var.web_acl_arn != null
    error_message = "web_acl_enabled = true requiere web_acl_arn."
  }
}

variable "xray_tracing_enabled" {
  description = "Trazas de X-Ray en API Gateway. false por defecto: la aplicación usa OpenTelemetry de extremo a extremo y activar ambas duplica trazas (ADR 0008)."
  type        = bool
  default     = false
  nullable    = false
}

variable "logging_level" {
  description = "Logs de ejecución de API Gateway: OFF, ERROR (por defecto) o INFO. Nunca se registran cuerpos (data_trace desactivado). Requieren el rol de CloudWatch de la cuenta (manage_account_logging_role en una instancia por cuenta y región)."
  type        = string
  default     = "ERROR"

  validation {
    condition     = contains(["OFF", "ERROR", "INFO"], var.logging_level)
    error_message = "logging_level debe ser OFF, ERROR o INFO."
  }

  nullable = false
}

variable "manage_account_logging_role" {
  description = "Crea el rol que API Gateway usa para escribir en CloudWatch Logs y lo fija en la configuración de la cuenta (aws_api_gateway_account). Es un ajuste único por cuenta y región, necesario para los logs de acceso y de ejecución de cualquier REST API: actívalo en UNA sola instancia."
  type        = bool
  default     = false
  nullable    = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK del entorno que cifra los log groups de acceso y ejecución. Su política debe autorizar al principal logs.<región>.amazonaws.com."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "log_retention_days" {
  description = "Retención de los log groups, en días. En prod, al menos 90."
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
  description = "Publica en SSM Parameter Store, bajo /<project>/<env>/api/<name>/, el ID de la API, la URL de la etapa y los IDs de los planes de uso (los necesita el onboarding para asociar las API keys)."
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
