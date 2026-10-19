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
  description = "Entorno de despliegue. En prod el ALB lleva protección contra borrado."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "name" {
  description = "Nombre del ALB (máx. 32 caracteres). Si es null: <project>-<environment>. Útil cuando un entorno necesita más de un ALB."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$", var.name))
    error_message = "name debe tener 1-32 caracteres: minúsculas, dígitos y guiones, sin guion al principio ni al final."
  }
}

variable "vpc_id" {
  description = "ID de la VPC donde se crea el ALB."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "subnet_ids" {
  description = "Subredes de la capa app (privadas) del ALB, en al menos 2 AZ (output subnet_ids[\"app\"] de network/vpc)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2 && length(distinct(var.subnet_ids)) == length(var.subnet_ids)
    error_message = "Indica al menos 2 subredes distintas (una por AZ)."
  }

  validation {
    condition     = alltrue([for s in var.subnet_ids : can(regex("^subnet-[0-9a-f]+$", s))])
    error_message = "Cada subred debe tener el formato subnet-xxxxxxxx."
  }

  nullable = false
}

variable "certificate_arn" {
  description = "Certificado ACM REGIONAL (de la región del ALB, emitido) del dominio público de la aplicación. CloudFront reenvía el Host del visitante y valida este certificado (ADR 0007)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:acm:[a-z0-9-]+:[0-9]{12}:certificate/", var.certificate_arn))
    error_message = "certificate_arn debe ser el ARN de un certificado de ACM."
  }

  nullable = false
}

variable "ssl_policy" {
  description = "Política TLS del listener HTTPS. Por defecto TLS 1.3 con respaldo a 1.2."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  validation {
    condition = contains([
      "ELBSecurityPolicy-TLS13-1-2-2021-06",
      "ELBSecurityPolicy-TLS13-1-2-Res-2021-06",
      "ELBSecurityPolicy-TLS13-1-2-Ext1-2021-06",
      "ELBSecurityPolicy-TLS13-1-2-Ext2-2021-06",
      "ELBSecurityPolicy-TLS13-1-3-2021-06",
      "ELBSecurityPolicy-FS-1-2-Res-2020-10",
      "ELBSecurityPolicy-TLS-1-2-2017-01",
      "ELBSecurityPolicy-TLS-1-2-Ext-2018-06",
    ], var.ssl_policy)
    error_message = "ssl_policy debe ser una política TLS 1.2+ de la lista permitida; las que admiten TLS 1.0/1.1 no están permitidas."
  }

  nullable = false
}

variable "idle_timeout_seconds" {
  description = "Segundos de inactividad antes de cerrar la conexión (1-4000). Debe ser menor que el timeout de lectura del origen en CloudFront."
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout_seconds >= 1 && var.idle_timeout_seconds <= 4000
    error_message = "idle_timeout_seconds debe estar entre 1 y 4000."
  }

  nullable = false
}

variable "target_groups" {
  description = "Target groups de tipo ip (Fargate), por clave estable. El nombre real es <project>-<environment>-<clave> (máx. 32 caracteres). El protocolo ALB→tarea es HTTP por defecto: el tráfico no sale de las subredes privadas; usa HTTPS si el contenedor sirve TLS."
  type = map(object({
    port                 = number
    protocol             = optional(string, "HTTP")
    protocol_version     = optional(string, "HTTP1")
    deregistration_delay = optional(number, 30)
    health_check = optional(object({
      path                = optional(string, "/")
      port                = optional(string, "traffic-port")
      matcher             = optional(string, "200-399")
      interval            = optional(number, 30)
      timeout             = optional(number, 5)
      healthy_threshold   = optional(number, 3)
      unhealthy_threshold = optional(number, 3)
    }), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for k in keys(var.target_groups) : can(regex("^[a-z0-9]([a-z0-9-]{0,14}[a-z0-9])?$", k))])
    error_message = "Las claves de target_groups deben tener 1-16 caracteres: minúsculas, dígitos y guiones, sin guion al principio ni al final."
  }

  validation {
    condition     = alltrue([for k in keys(var.target_groups) : length("${var.project}-${var.environment}-${k}") <= 32])
    error_message = "El nombre <project>-<environment>-<clave> de cada target group no puede superar 32 caracteres."
  }

  validation {
    condition     = alltrue([for t in values(var.target_groups) : t.port >= 1 && t.port <= 65535])
    error_message = "El puerto de cada target group debe estar entre 1 y 65535."
  }

  validation {
    condition     = alltrue([for t in values(var.target_groups) : contains(["HTTP", "HTTPS"], t.protocol) && contains(["HTTP1", "HTTP2", "GRPC"], t.protocol_version)])
    error_message = "protocol debe ser HTTP o HTTPS y protocol_version HTTP1, HTTP2 o GRPC."
  }

  validation {
    condition     = alltrue([for t in values(var.target_groups) : t.deregistration_delay >= 0 && t.deregistration_delay <= 3600])
    error_message = "deregistration_delay debe estar entre 0 y 3600 segundos."
  }

  validation {
    condition     = alltrue([for t in values(var.target_groups) : t.health_check.timeout < t.health_check.interval])
    error_message = "El timeout del health check debe ser menor que su intervalo."
  }
}

variable "listener_rules" {
  description = "Reglas del listener 443, por clave estable. Cada regla exige al menos un host-header o path y apunta a una clave de target_groups. Incluye una regla por el dominio público: la acción por defecto es un 404, así el ALB no sirve nada a quien llegue por su DNS interno o con otro Host."
  type = map(object({
    priority      = number
    target_group  = string
    host_headers  = optional(list(string), [])
    path_patterns = optional(list(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for r in values(var.listener_rules) : r.priority >= 1 && r.priority <= 50000])
    error_message = "priority debe estar entre 1 y 50000."
  }

  validation {
    condition     = length(distinct([for r in values(var.listener_rules) : r.priority])) == length(var.listener_rules)
    error_message = "Las prioridades de las reglas deben ser únicas."
  }

  validation {
    condition     = alltrue([for r in values(var.listener_rules) : length(r.host_headers) + length(r.path_patterns) > 0])
    error_message = "Cada regla necesita al menos un host_headers o path_patterns (una regla sin condición dejaría pasar todo el tráfico)."
  }

  validation {
    condition     = alltrue([for r in values(var.listener_rules) : contains(keys(var.target_groups), r.target_group)])
    error_message = "target_group de cada regla debe ser una clave de target_groups."
  }
}

variable "egress_targets" {
  description = "Security groups de destino hacia los que el ALB puede salir, por clave estable (p. ej. el SG del servicio ECS) y el puerto de la app. Es la ÚNICA salida del ALB. Las claves deben ser conocidas al planificar; los IDs pueden depender de otros recursos."
  type = map(object({
    security_group_id = string
    port              = number
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for t in values(var.egress_targets) : t.port >= 1 && t.port <= 65535])
    error_message = "El puerto de cada egress_target debe estar entre 1 y 65535."
  }
}

variable "access_logs_bucket_name" {
  description = "Bucket S3 de logs de acceso del ALB (cifrado SSE-S3: el ALB no admite SSE-KMS en el bucket de logs). Debe autorizar la entrega del ALB (ver examples/complete). Obligatorio en prod; null = sin logs."
  type        = string
  default     = null

  validation {
    condition     = var.access_logs_bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.access_logs_bucket_name))
    error_message = "access_logs_bucket_name debe ser un nombre de bucket S3 válido."
  }

  validation {
    condition     = var.environment != "prod" || var.access_logs_bucket_name != null
    error_message = "En prod los logs de acceso del ALB son obligatorios (access_logs_bucket_name)."
  }
}

variable "access_logs_prefix" {
  description = "Prefijo de los logs de acceso dentro del bucket."
  type        = string
  default     = "alb"
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
