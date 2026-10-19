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
  description = "Prefijo de los recursos (p. ej. acme-prod-aurora): el secreto se llama <name>/app_runtime y la función de rotación <name>-rotation."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,49}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-50 caracteres), empezando por letra."
  }

  nullable = false
}

variable "vpc_id" {
  description = "VPC donde se crea el security group de la función de rotación."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "db_security_group_id" {
  description = "Security group de la base de datos. El módulo le añade una regla de entrada desde la función de rotación."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]{8,17}$", var.db_security_group_id))
    error_message = "db_security_group_id debe tener el formato sg-xxxxxxxx."
  }

  nullable = false
}

variable "db_port" {
  description = "Puerto de PostgreSQL."
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port >= 1024 && var.db_port <= 65535
    error_message = "db_port debe estar entre 1024 y 65535."
  }

  nullable = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK que cifra el secreto de la aplicación (y la que cifra el secreto maestro, a la que la función de rotación necesita acceso)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "master_secret_arn" {
  description = "ARN del secreto maestro gestionado por RDS. Obligatorio si se activa la rotación: la función lo usa para crear/alternar el segundo usuario."
  type        = string
  default     = null

  validation {
    condition     = var.master_secret_arn == null || can(regex("^arn:[a-z-]+:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:", var.master_secret_arn))
    error_message = "master_secret_arn debe ser el ARN de un secreto de Secrets Manager."
  }
}

variable "db_host" {
  description = "Endpoint de la base de datos (writer de Aurora o instancia RDS). Va en la versión inicial del secreto junto con el puerto, la base y el usuario: la rotación multiusuario y la aplicación lo leen de ahí."
  type        = string
  default     = null
}

variable "db_name" {
  description = "Base de datos de la aplicación (clave dbname del secreto)."
  type        = string
  default     = "app"
  nullable    = false
}

variable "app_username" {
  description = "Rol SQL de la aplicación que crea el bootstrap (sql/00-app-runtime.sql). La rotación multiusuario alterna entre <app_username> y <app_username>_clone."
  type        = string
  default     = "app_runtime"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,40}$", var.app_username))
    error_message = "app_username debe ser minúsculas, dígitos y guiones bajos, empezando por letra."
  }

  nullable = false
}

variable "rotation" {
  description = "Rotación multiusuario del secreto de la aplicación con la función PostgreSQLMultiUser que genera CloudFormation (HostedRotationLambda). subnet_ids son subredes con ruta al endpoint de Secrets Manager (capa app) y endpoint_security_group_id el SG del endpoint de interfaz de Secrets Manager. null = sin rotación (no permitido en prod)."
  type = object({
    subnet_ids                 = list(string)
    endpoint_security_group_id = string
    automatically_after_days   = optional(number, 30)
  })
  default = null

  validation {
    condition     = var.rotation == null || length(var.rotation.subnet_ids) >= 2
    error_message = "rotation.subnet_ids necesita al menos 2 subredes (2 AZ)."
  }

  validation {
    condition     = var.rotation == null || can(regex("^sg-[0-9a-f]{8,17}$", var.rotation.endpoint_security_group_id))
    error_message = "rotation.endpoint_security_group_id debe tener el formato sg-xxxxxxxx."
  }

  validation {
    condition     = var.rotation == null || (var.rotation.automatically_after_days >= 1 && var.rotation.automatically_after_days <= 365)
    error_message = "rotation.automatically_after_days debe estar entre 1 y 365."
  }

  validation {
    condition     = var.rotation == null || var.master_secret_arn != null
    error_message = "La rotación necesita master_secret_arn."
  }

  validation {
    condition     = var.rotation == null || var.db_host != null
    error_message = "La rotación necesita db_host (va en la versión inicial del secreto)."
  }

  validation {
    condition     = var.environment != "prod" || var.rotation != null
    error_message = "En prod el secreto de la aplicación debe tener rotación configurada."
  }
}

variable "log_retention_days" {
  description = "Retención del log group de la función de rotación, en días (valores admitidos por CloudWatch Logs). En prod, al menos 90."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days debe ser un valor admitido por CloudWatch Logs."
  }

  validation {
    condition     = var.environment != "prod" || var.log_retention_days >= 90
    error_message = "En prod la retención de logs debe ser de al menos 90 días."
  }

  nullable = false
}

variable "recovery_window_in_days" {
  description = "Días de recuperación del secreto tras borrarlo (7-30). 0 = borrado inmediato, solo fuera de prod (sandbox y pruebas de integración: el nombre queda libre al momento). null = 30 en prod y 7 en el resto."
  type        = number
  default     = null

  validation {
    condition     = var.recovery_window_in_days == null || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30) || (var.recovery_window_in_days == 0 && var.environment != "prod")
    error_message = "recovery_window_in_days debe estar entre 7 y 30 (0 solo fuera de prod)."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
