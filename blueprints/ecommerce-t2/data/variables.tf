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

variable "engine_version" {
  description = "Versión de PostgreSQL (comprobar las disponibles con `aws rds describe-db-engine-versions --engine postgres`)."
  type        = string
  default     = "17.11"
  nullable    = false
}

variable "instance_class" {
  description = "Clase de la instancia. null = db.m7g.large en prod y db.t4g.micro en el resto (la más barata con Graviton)."
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Standby síncrono en otra AZ. null = true en prod y false en el resto (el blueprint T2 es Multi-AZ en prod)."
  type        = bool
  default     = null
}

variable "storage" {
  description = "Almacenamiento gp3: allocated_gb inicial y max_allocated_gb del autoescalado (0 lo desactiva)."
  type = object({
    allocated_gb     = optional(number, 20)
    max_allocated_gb = optional(number, 100)
  })
  default  = {}
  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
