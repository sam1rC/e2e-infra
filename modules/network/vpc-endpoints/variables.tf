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

variable "vpc_id" {
  description = "ID de la VPC donde se crean los endpoints."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "vpc_cidr_block" {
  description = "CIDR de la VPC (solo se usa si vpc_cidr_fallback = true)."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "vpc_cidr_block debe ser un CIDR IPv4 válido."
  }

  nullable = false
}

variable "subnet_ids" {
  description = "Subredes de la capa app (una por AZ, mínimo 2) donde se crean las interfaces de los endpoints."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Indica al menos dos subredes (una por AZ) para los endpoints de interfaz."
  }

  nullable = false
}

variable "route_table_ids" {
  description = "Tablas de rutas (app y data) a las que se asocian los endpoints de tipo gateway."
  type        = list(string)

  validation {
    condition     = length(var.route_table_ids) >= 1
    error_message = "Indica al menos una tabla de rutas para los endpoints gateway."
  }

  nullable = false
}

variable "interface_services" {
  description = "Servicios con endpoint de interfaz (nombre sin el prefijo com.amazonaws.<región>.). Opcionales habituales: ssm, ssmmessages, ec2messages, monitoring, xray (trazas OTLP sin NAT), rds-data, elasticache, events, sqs, sns."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "logs", "secretsmanager", "sts", "kms"]

  validation {
    condition     = alltrue([for s in var.interface_services : can(regex("^[a-z0-9][a-z0-9.-]*$", s))])
    error_message = "Cada servicio debe indicarse sin prefijo (p. ej. ecr.api, logs, sts)."
  }

  validation {
    condition     = length(distinct(var.interface_services)) == length(var.interface_services)
    error_message = "interface_services no puede contener duplicados."
  }

  nullable = false
}

variable "gateway_services" {
  description = "Servicios con endpoint de tipo gateway (gratuitos)."
  type        = list(string)
  default     = ["s3", "dynamodb"]

  validation {
    condition     = alltrue([for s in var.gateway_services : contains(["s3", "dynamodb"], s)])
    error_message = "gateway_services solo admite s3 y dynamodb."
  }

  nullable = false
}

variable "allowed_security_group_ids" {
  description = "Security groups de aplicación autorizados a usar los endpoints de interfaz (puerto 443), como mapa nombre estable => ID. Un mapa (y no una lista) permite pasar IDs que aún no existen: las claves son conocidas al planificar."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "vpc_cidr_fallback" {
  description = "Permite además la entrada 443 desde todo el CIDR de la VPC. Es más permisivo: úsalo solo si no puedes enumerar los security groups de aplicación."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = var.vpc_cidr_fallback || length(var.allowed_security_group_ids) > 0 || var.ingress_from_other_layers
    error_message = "Indica allowed_security_group_ids, activa vpc_cidr_fallback o declara ingress_from_other_layers: sin ninguno, los endpoints de interfaz serían inalcanzables."
  }
}

variable "ingress_from_other_layers" {
  description = "Las reglas de entrada 443 las añaden las capas que consumen los endpoints (data, app), sobre el security group que publica este módulo (security_group_id): es el patrón de los blueprints por capas, donde los SG de las tareas y de la rotación aún no existen al desplegar la red (ADR 0016). Solo relaja la validación; no abre nada."
  type        = bool
  default     = false
  nullable    = false
}

variable "s3_allowed_account_ids" {
  description = "Cuentas adicionales cuyos buckets puede alcanzar el endpoint de S3 (la cuenta actual siempre está permitida)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.s3_allowed_account_ids : can(regex("^[0-9]{12}$", a))])
    error_message = "Cada cuenta debe ser un ID de 12 dígitos."
  }

  nullable = false
}

variable "s3_additional_bucket_arns" {
  description = "Buckets de S3 de AWS o de terceros (ARN del bucket, sin /*) con acceso de lectura a través del endpoint, además del bucket de capas de ECR de la región."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
