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


variable "aurora" {
  description = "Aurora PostgreSQL provisionado: versión, clase (null = db.r7g.large en prod y db.t4g.medium en el resto), instancias (null = 2 en prod —writer y lector en AZ distintas— y 1 en el resto) y Database Insights (null = advanced en prod, standard en el resto)."
  type = object({
    engine_version         = optional(string, "17.11")
    instance_class         = optional(string)
    instance_count         = optional(number)
    database_insights_mode = optional(string)
  })
  default  = {}
  nullable = false
}

variable "cache" {
  description = "ElastiCache Valkey con autenticación IAM (sin contraseñas). En SaaS T1 es opcional y está desactivado por defecto (enabled = true para activarlo). node_type null = cache.m7g.large en prod y cache.t4g.micro en el resto; num_cache_clusters null = 2 en prod y 1 en el resto."
  type = object({
    enabled            = optional(bool, true)
    engine_version     = optional(string, "8.2")
    node_type          = optional(string)
    num_cache_clusters = optional(number)
  })
  default  = { enabled = false }
  nullable = false
}

variable "dr_copy" {
  description = "Copia de los backups a la región de DR (provider aws.dr): RPO de 24 h ante la caída de la región (plan 9.1.1). null = true en prod y false en el resto."
  type        = bool
  default     = null
}

variable "restore_testing" {
  description = "Pruebas de restauración automáticas de AWS Backup (mensuales, restauran el último recovery point de Aurora y lo borran). null = true en prod y false en el resto."
  type        = bool
  default     = null
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
