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
  description = "Identificador del replication group (también prefijo de usuarios, grupo y parameter group). Si es null: <project>-<environment>-valkey. Máximo 23 caracteres: los IDs de usuario de ElastiCache admiten 40 y llevan el sufijo -<clave> (hasta 16)."
  type        = string
  default     = null

  validation {
    condition     = var.name == null || can(regex("^[a-z][a-z0-9-]{1,21}[a-z0-9]$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (3-23 caracteres), empezando por letra y sin terminar en guion."
  }

  validation {
    condition     = var.name != null || can(regex("^[a-z][a-z0-9-]{1,21}[a-z0-9]$", "${var.project}-${var.environment}-valkey"))
    error_message = "El nombre por defecto <project>-<environment>-valkey supera los 23 caracteres: indica name o usa un project más corto."
  }
}

variable "vpc_id" {
  description = "VPC donde se crea el security group."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "subnet_ids" {
  description = "Subredes de la capa data (al menos 2, en AZ distintas) para el subnet group."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids necesita al menos 2 subredes (2 AZ)."
  }

  nullable = false
}

variable "allowed_security_group_ids" {
  description = "Security groups autorizados a conectar al puerto de Valkey, como mapa nombre estable => ID. Un mapa (y no una lista) permite pasar IDs que aún no existen: las claves son conocidas al planificar. El SG no tiene reglas de salida."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK del entorno: cifra los datos en reposo, las copias y los log groups. Su política debe autorizar a logs.<región>.amazonaws.com (service_principals de foundation/kms-key) y a ElastiCache vía kms:ViaService."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "engine_version" {
  description = "Versión de Valkey (7.2 o superior; la autenticación IAM exige >= 7.2 con TLS). Verifica las disponibles con `aws elasticache describe-cache-engine-versions --engine valkey`. La familia del parameter group (valkey7, valkey8...) se deduce de la versión mayor."
  type        = string
  default     = "8.2"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.engine_version)) && tonumber(split(".", var.engine_version)[0]) * 100 + tonumber(split(".", var.engine_version)[1]) >= 702
    error_message = "engine_version debe ser <mayor>.<minor> y al menos 7.2 (p. ej. 7.2, 8.2 o 9.0)."
  }

  nullable = false
}

variable "node_type" {
  description = "Tipo de nodo (Graviton: cache.t4g.small en dev, cache.m7g.large o mayor en prod)."
  type        = string
  default     = "cache.t4g.small"

  validation {
    condition     = can(regex("^cache\\.[a-z0-9]+\\.[a-z0-9]+$", var.node_type))
    error_message = "node_type debe tener el formato cache.<familia>.<tamaño>."
  }

  nullable = false
}

variable "num_cache_clusters" {
  description = "Número de nodos (1 primario + réplicas). Con 2 o más se activan failover automático y Multi-AZ. null = 2 en prod y 1 en el resto; en prod, mínimo 2."
  type        = number
  default     = null

  validation {
    condition     = var.num_cache_clusters == null || (var.num_cache_clusters >= 1 && var.num_cache_clusters <= 6)
    error_message = "num_cache_clusters debe estar entre 1 y 6."
  }

  validation {
    condition     = var.environment != "prod" || coalesce(var.num_cache_clusters, 2) >= 2
    error_message = "En prod se necesitan al menos 2 nodos (primario y réplica en AZ distintas)."
  }
}

variable "port" {
  description = "Puerto de Valkey."
  type        = number
  default     = 6379

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "port debe estar entre 1024 y 65535."
  }

  nullable = false
}

variable "maxmemory_policy" {
  description = "Política de expulsión cuando se llena la memoria: volatile-lru (caché con TTL), allkeys-lru, allkeys-lfu, volatile-lfu, volatile-random, allkeys-random, volatile-ttl o noeviction (sesiones o colas: devuelve error en vez de expulsar)."
  type        = string
  default     = "volatile-lru"

  validation {
    condition     = contains(["volatile-lru", "allkeys-lru", "volatile-lfu", "allkeys-lfu", "volatile-random", "allkeys-random", "volatile-ttl", "noeviction"], var.maxmemory_policy)
    error_message = "maxmemory_policy no es una política de Valkey válida."
  }

  nullable = false
}

variable "iam_users" {
  description = "Usuarios de aplicación con autenticación IAM, por clave estable (el user_id es <name>-<clave>). access_string es el ACL de Valkey: por defecto todo salvo los comandos peligrosos (FLUSHALL, KEYS, CONFIG...). No hay usuario default: sin un usuario IAM nadie conecta. No hay contraseñas ni AUTH token."
  type = map(object({
    access_string = optional(string, "on ~* +@all -@dangerous")
  }))
  default = {
    app = {}
  }
  nullable = false

  validation {
    condition     = length(var.iam_users) >= 1
    error_message = "Declara al menos un usuario IAM: sin él nadie podría conectar (no hay usuario default)."
  }

  validation {
    condition     = alltrue([for k in keys(var.iam_users) : can(regex("^[a-z][a-z0-9]{0,15}$", k))])
    error_message = "Las claves de iam_users deben ser minúsculas y dígitos (1-16 caracteres), empezando por letra."
  }

  validation {
    condition     = alltrue([for u in values(var.iam_users) : startswith(u.access_string, "on ")])
    error_message = "access_string debe empezar por \"on \": un usuario IAM desactivado no podría conectar."
  }
}

variable "snapshots" {
  description = "Copias de seguridad diarias: retention_days (0 las desactiva; en prod, al menos 7) y window (hh:mm-hh:mm UTC, sin solaparse con maintenance_window)."
  type = object({
    retention_days     = optional(number, 7)
    window             = optional(string, "03:00-04:00")
    maintenance_window = optional(string, "sun:05:00-sun:06:00")
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.snapshots.retention_days >= 0 && var.snapshots.retention_days <= 35
    error_message = "snapshots.retention_days debe estar entre 0 y 35."
  }

  validation {
    condition     = var.environment != "prod" || var.snapshots.retention_days >= 7
    error_message = "En prod snapshots.retention_days debe ser al menos 7."
  }

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$", var.snapshots.window))
    error_message = "snapshots.window debe tener el formato hh:mm-hh:mm (UTC)."
  }

  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([01][0-9]|2[0-3]):[0-5][0-9]$", var.snapshots.maintenance_window))
    error_message = "snapshots.maintenance_window debe tener el formato ddd:hh:mm-ddd:hh:mm (UTC, en minúsculas)."
  }
}

variable "final_snapshot_enabled" {
  description = "Crea una copia final (<name>-final) al destruir el replication group. Si ya existe una con ese nombre, la destrucción falla: bórrala antes. Obligatoria en prod."
  type        = bool
  default     = true
  nullable    = false

  validation {
    condition     = var.environment != "prod" || var.final_snapshot_enabled
    error_message = "En prod la copia final no puede desactivarse."
  }
}

variable "log_retention_days" {
  description = "Retención de los log groups de slow-log y engine-log, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90."
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

variable "apply_immediately" {
  description = "Aplica los cambios sin esperar a la ventana de mantenimiento (útil en dev; en prod mejor false)."
  type        = bool
  default     = false
  nullable    = false
}

variable "publish_ssm_parameters" {
  description = "Publica endpoints y ARNs en SSM Parameter Store bajo /<project>/<env>/data/<ssm_namespace>/ para las capas consumidoras."
  type        = bool
  default     = true
  nullable    = false
}

variable "ssm_namespace" {
  description = "Segmento de la ruta SSM (evita colisiones si hay más de un Valkey en el entorno)."
  type        = string
  default     = "valkey"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.ssm_namespace))
    error_message = "ssm_namespace debe ser minúsculas, dígitos y guiones (2-31 caracteres)."
  }

  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
