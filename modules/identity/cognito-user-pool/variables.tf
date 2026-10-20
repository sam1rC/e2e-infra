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
  description = "Nombre lógico del user pool (p. ej. customers, tenants, tier-pro); el nombre real es <project>-<environment>-<name>. En SaaS T1 el blueprint instancia el módulo por tier o por tenant (pool_strategy) con claves estables."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-31 caracteres), empezando por letra."
  }

  nullable = false
}

variable "feature_plan" {
  description = "Plan de funcionalidades de Cognito (user_pool_tier): LITE, ESSENTIALS (por defecto; incluye managed login, pre token generation v2 para personalizar el access token e historial de contraseñas) o PLUS (añade threat protection: credenciales comprometidas, autenticación adaptativa y logs de actividad; SaaS T1). Bajar de PLUS exige desactivar antes la threat protection."
  type        = string
  default     = "ESSENTIALS"

  validation {
    condition     = contains(["LITE", "ESSENTIALS", "PLUS"], var.feature_plan)
    error_message = "feature_plan debe ser LITE, ESSENTIALS o PLUS."
  }

  nullable = false
}

variable "mfa_configuration" {
  description = "MFA del pool (afecta a todos los usuarios: Cognito no admite MFA por grupo): ON, OPTIONAL u OFF. null = ON en prod y OPTIONAL en el resto. El único factor configurado es TOTP. En prod OFF no se admite y OPTIONAL solo con feature_plan = PLUS y threat protection ENFORCED (MFA adaptativa por riesgo). Si los administradores necesitan MFA obligatoria y los usuarios finales no, usa un pool aparte para administradores."
  type        = string
  default     = null

  validation {
    condition     = var.mfa_configuration == null || contains(["ON", "OPTIONAL", "OFF"], coalesce(var.mfa_configuration, "ON"))
    error_message = "mfa_configuration debe ser ON, OPTIONAL u OFF."
  }

  validation {
    condition     = var.environment != "prod" || var.mfa_configuration != "OFF"
    error_message = "En prod la MFA no puede estar desactivada."
  }

  validation {
    condition     = var.environment != "prod" || var.mfa_configuration != "OPTIONAL" || (var.feature_plan == "PLUS" && contains(["ENFORCED", "DEFAULT"], coalesce(var.threat_protection.mode, "DEFAULT")))
    error_message = "En prod, mfa_configuration = OPTIONAL requiere feature_plan = PLUS con threat protection ENFORCED (MFA adaptativa); si no, usa ON."
  }
}

variable "password_policy" {
  description = "Política de contraseñas. minimum_length al menos 12; password_history_size (0-24) solo se aplica en ESSENTIALS y PLUS."
  type = object({
    minimum_length                   = optional(number, 14)
    require_lowercase                = optional(bool, true)
    require_uppercase                = optional(bool, true)
    require_numbers                  = optional(bool, true)
    require_symbols                  = optional(bool, true)
    temporary_password_validity_days = optional(number, 3)
    password_history_size            = optional(number, 5)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.password_policy.minimum_length >= 12 && var.password_policy.minimum_length <= 99
    error_message = "password_policy.minimum_length debe estar entre 12 y 99."
  }

  validation {
    condition     = var.password_policy.password_history_size >= 0 && var.password_policy.password_history_size <= 24 && var.password_policy.temporary_password_validity_days >= 1 && var.password_policy.temporary_password_validity_days <= 7
    error_message = "password_history_size debe estar entre 0 y 24 y temporary_password_validity_days entre 1 y 7."
  }
}

variable "deletion_protection" {
  description = "Protección contra borrado del pool (borrarlo elimina a todos los usuarios). null = activa fuera de dev. En prod no se puede desactivar."
  type        = bool
  default     = null

  validation {
    condition     = var.environment != "prod" || var.deletion_protection != false
    error_message = "En prod deletion_protection no puede ser false."
  }
}

variable "self_registration_enabled" {
  description = "Permite que los usuarios se registren solos (tienda online). false = solo el backend crea usuarios (onboarding SaaS, que asigna custom:tenant_id con credenciales de administrador)."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !(var.self_registration_enabled && var.tenant_id_attribute)
    error_message = "Un pool con tenant_id_attribute no admite registro libre: el tenant lo asigna el onboarding."
  }
}

variable "tenant_id_attribute" {
  description = "Crea el atributo personalizado custom:tenant_id (inmutable tras el alta y no escribible por los app clients). Lo asigna el backend de onboarding con AdminCreateUser; las APIs lo leen del token validado. No se puede borrar ni renombrar una vez creado."
  type        = bool
  default     = false
  nullable    = false
}

variable "groups" {
  description = "Grupos del pool por nombre estable (p. ej. admins). precedence: menor valor = mayor prioridad cuando un usuario está en varios grupos."
  type = map(object({
    description = optional(string, "")
    precedence  = optional(number)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.groups) : can(regex("^[A-Za-z0-9_-]{1,128}$", k))])
    error_message = "Los nombres de grupo deben ser letras, dígitos, guiones o guiones bajos (1-128)."
  }
}

variable "app_clients" {
  description = "App clients públicos (SPA o móvil) por clave estable: sin secreto, OAuth authorization code con PKCE, solo SRP para la autenticación directa, revocación de tokens y rotación de refresh tokens. Los tokens de acceso e ID duran 15-60 minutos. write_attributes nunca puede incluir custom:tenant_id. Los clientes confidenciales no se crean aquí: su secreto quedaría en el estado (regla 0.1)."
  type = map(object({
    callback_urls                 = list(string)
    logout_urls                   = optional(list(string), [])
    oauth_scopes                  = optional(list(string), ["openid", "email", "profile"])
    access_token_validity_minutes = optional(number, 60)
    id_token_validity_minutes     = optional(number, 60)
    refresh_token_validity_days   = optional(number, 30)
    refresh_token_rotation        = optional(bool, true)
    read_attributes               = optional(list(string))
    write_attributes              = optional(list(string), ["email", "name"])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.app_clients) : can(regex("^[a-z][a-z0-9-]{1,30}$", k))])
    error_message = "Las claves de app_clients deben ser minúsculas, dígitos y guiones (2-31 caracteres)."
  }

  validation {
    condition = alltrue([
      for c in values(var.app_clients) :
      length(c.callback_urls) >= 1 && alltrue([for u in concat(c.callback_urls, c.logout_urls) : can(regex("^(https://[^\\s*]+|http://localhost(:[0-9]+)?(/[^\\s*]*)?)$", u))])
    ])
    error_message = "Cada app client necesita al menos una callback_url; todas las URLs deben ser https:// (o http://localhost para desarrollo) y sin comodines."
  }

  validation {
    condition     = var.environment != "prod" || alltrue([for c in values(var.app_clients) : alltrue([for u in concat(c.callback_urls, c.logout_urls) : startswith(u, "https://")])])
    error_message = "En prod las callback_urls y logout_urls deben ser https://."
  }

  validation {
    condition = alltrue([
      for c in values(var.app_clients) :
      c.access_token_validity_minutes >= 15 && c.access_token_validity_minutes <= 60 &&
      c.id_token_validity_minutes >= 15 && c.id_token_validity_minutes <= 60 &&
      c.refresh_token_validity_days >= 1 && c.refresh_token_validity_days <= 90
    ])
    error_message = "access/id tokens: 15-60 minutos; refresh token: 1-90 días."
  }

  validation {
    condition     = alltrue([for c in values(var.app_clients) : !contains(c.write_attributes, "custom:tenant_id")])
    error_message = "write_attributes no puede incluir custom:tenant_id: solo lo asigna el backend de onboarding."
  }

  validation {
    condition     = alltrue([for c in values(var.app_clients) : length(c.oauth_scopes) >= 1 && contains(c.oauth_scopes, "openid")])
    error_message = "oauth_scopes debe incluir openid."
  }
}

variable "domain" {
  description = "Dominio de managed login (versión 2): prefix (https://<prefix>.auth.<región>.amazoncognito.com) o custom_domain + certificate_arn (certificado ACM en us-east-1). null = sin dominio (solo autenticación directa con SRP)."
  type = object({
    prefix          = optional(string)
    custom_domain   = optional(string)
    certificate_arn = optional(string)
  })
  default = null

  validation {
    condition     = var.domain == null || ((try(var.domain.prefix, null) == null) != (try(var.domain.custom_domain, null) == null))
    error_message = "domain necesita exactamente uno de prefix o custom_domain."
  }

  validation {
    condition     = try(var.domain.prefix, null) == null || (can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$", var.domain.prefix)) && !can(regex("aws|amazon|cognito", var.domain.prefix)))
    error_message = "domain.prefix debe ser minúsculas, dígitos y guiones (1-63) y no contener aws, amazon ni cognito (reservados)."
  }

  validation {
    condition     = try(var.domain.custom_domain, null) == null || can(regex("^arn:aws[a-z-]*:acm:us-east-1:[0-9]{12}:certificate/", var.domain.certificate_arn))
    error_message = "Con custom_domain, certificate_arn debe ser un certificado ACM de us-east-1."
  }
}

variable "threat_protection" {
  description = "Threat protection (solo con feature_plan = PLUS). mode: AUDIT (solo registra) o ENFORCED; null = ENFORCED en prod y AUDIT en el resto. compromised_credentials_action: BLOCK o NO_ACTION para inicio de sesión, alta y cambio de contraseña. low/medium/high_action (autenticación adaptativa): NO_ACTION, MFA_IF_CONFIGURED, MFA_REQUIRED o BLOCK. notify (opcional): identidad SES verificada para avisar al usuario en riesgo medio y alto."
  type = object({
    mode                           = optional(string)
    compromised_credentials_action = optional(string, "BLOCK")
    low_action                     = optional(string, "NO_ACTION")
    medium_action                  = optional(string, "MFA_IF_CONFIGURED")
    high_action                    = optional(string, "MFA_REQUIRED")
    notify = optional(object({
      source_arn = string
      from       = optional(string)
      reply_to   = optional(string)
    }))
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.threat_protection.mode == null || contains(["AUDIT", "ENFORCED"], coalesce(var.threat_protection.mode, "AUDIT"))
    error_message = "threat_protection.mode debe ser AUDIT o ENFORCED."
  }

  validation {
    condition = contains(["BLOCK", "NO_ACTION"], var.threat_protection.compromised_credentials_action) && alltrue([
      for a in [var.threat_protection.low_action, var.threat_protection.medium_action, var.threat_protection.high_action] :
      contains(["NO_ACTION", "MFA_IF_CONFIGURED", "MFA_REQUIRED", "BLOCK"], a)
    ])
    error_message = "compromised_credentials_action: BLOCK o NO_ACTION; low/medium/high_action: NO_ACTION, MFA_IF_CONFIGURED, MFA_REQUIRED o BLOCK."
  }

  validation {
    condition     = var.threat_protection.notify == null || can(regex("^arn:aws[a-z-]*:ses:[a-z0-9-]+:[0-9]{12}:identity/", var.threat_protection.notify.source_arn))
    error_message = "threat_protection.notify.source_arn debe ser el ARN de una identidad SES verificada."
  }
}

variable "pre_token_generation_lambda_arn" {
  description = "ARN de la Lambda del trigger pre token generation (versión V2_0), p. ej. para copiar custom:tenant_id al access token. Requiere ESSENTIALS o PLUS. El módulo concede a Cognito el permiso para invocarla. null = sin trigger."
  type        = string
  default     = null

  validation {
    condition     = var.pre_token_generation_lambda_arn == null || can(regex("^arn:aws[a-z-]*:lambda:[a-z0-9-]+:[0-9]{12}:function:[A-Za-z0-9_-]+(:[A-Za-z0-9_$-]+)?$", var.pre_token_generation_lambda_arn))
    error_message = "pre_token_generation_lambda_arn debe ser el ARN de una función Lambda."
  }

  validation {
    condition     = var.pre_token_generation_lambda_arn == null || var.feature_plan != "LITE"
    error_message = "El trigger pre token generation V2_0 requiere feature_plan ESSENTIALS o PLUS."
  }
}

variable "pre_token_generation_enabled" {
  description = "Activa el trigger pre token generation. Indícalo (true) cuando la Lambda se crea en el mismo apply: OpenTofu necesita conocer al planificar si se crea el permiso de invocación. null = activado si pre_token_generation_lambda_arn no es null."
  type        = bool
  default     = null

  validation {
    condition     = var.pre_token_generation_enabled != true || var.pre_token_generation_lambda_arn != null
    error_message = "pre_token_generation_enabled = true requiere pre_token_generation_lambda_arn."
  }
}

variable "email" {
  description = "Envío de correos (verificación, invitaciones, recuperación). COGNITO_DEFAULT está limitado a unos 50 correos al día: en prod usa DEVELOPER con una identidad SES verificada (source_arn) y from_email_address."
  type = object({
    sending_account    = optional(string, "COGNITO_DEFAULT")
    source_arn         = optional(string)
    from_email_address = optional(string)
    reply_to           = optional(string)
    configuration_set  = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["COGNITO_DEFAULT", "DEVELOPER"], var.email.sending_account)
    error_message = "email.sending_account debe ser COGNITO_DEFAULT o DEVELOPER."
  }

  validation {
    condition     = var.email.sending_account == "COGNITO_DEFAULT" || can(regex("^arn:aws[a-z-]*:ses:[a-z0-9-]+:[0-9]{12}:identity/", var.email.source_arn))
    error_message = "Con DEVELOPER, email.source_arn debe ser el ARN de una identidad SES verificada."
  }

  validation {
    condition     = var.environment != "prod" || var.email.sending_account == "DEVELOPER"
    error_message = "En prod los correos deben salir por SES (sending_account = DEVELOPER): el envío de Cognito está limitado a unos 50 al día."
  }
}

variable "kms_key_arn" {
  description = "ARN de la CMK del entorno que cifra los log groups de Cognito. Su política debe autorizar al principal logs.<región>.amazonaws.com."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "log_retention_days" {
  description = "Retención de los log groups (errores de envío de mensajes y, en PLUS, actividad de usuarios), en días. En prod, al menos 90."
  type        = number
  default     = 365

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
  description = "Publica en SSM Parameter Store, bajo /<project>/<env>/identity/<name>/, el ID y ARN del pool, el emisor (issuer) y los IDs de los app clients, para las capas que validan los JWT."
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
