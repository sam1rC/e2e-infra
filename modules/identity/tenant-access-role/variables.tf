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
  description = "Nombre lógico del rol; el nombre real es <project>-<environment>-<name>."
  type        = string
  default     = "tenant-access"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-31 caracteres), empezando por letra."
  }

  nullable = false
}

variable "trusted_role_arns" {
  description = "ARNs de los roles de ejecución de la aplicación (task role de ECS o rol de Lambda) que pueden asumir este rol pasando la etiqueta de sesión del tenant. Solo roles IAM: nunca la raíz de la cuenta, usuarios ni comodines."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.trusted_role_arns) >= 1 && alltrue([for a in var.trusted_role_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", a))])
    error_message = "trusted_role_arns debe contener al menos un ARN de rol IAM (arn:aws:iam::<cuenta>:role/<nombre>), sin comodines."
  }
}

variable "tenant_tag_key" {
  description = "Clave de la etiqueta de sesión (y del contexto de cifrado KMS) que lleva el identificador del tenant. La aplicación la fija en AssumeRole con el tenant del JWT validado."
  type        = string
  default     = "tenant"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,63}$", var.tenant_tag_key))
    error_message = "tenant_tag_key debe ser minúsculas, dígitos, guiones o guiones bajos (1-64 caracteres), empezando por letra."
  }

  nullable = false
}

variable "dynamodb_tables" {
  description = "Tablas DynamoDB en modo pool, por clave estable. El rol solo accede a los elementos cuya clave de partición sea exactamente el tenant de la sesión (dynamodb:LeadingKeys); la tabla debe crearse con tenant_partition_key = true (ADR 0006). include_indexes da acceso a <tabla>/index/* (todo índice debe tener tenant_id como clave de partición); read_only limita a lecturas."
  type = map(object({
    table_arn       = string
    include_indexes = optional(bool, true)
    read_only       = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for t in values(var.dynamodb_tables) : can(regex("^arn:aws[a-z-]*:dynamodb:[a-z0-9-]+:[0-9]{12}:table/[A-Za-z0-9_.-]{3,255}$", t.table_arn))])
    error_message = "Cada table_arn debe ser el ARN de una tabla DynamoDB (sin /index ni comodines)."
  }

  validation {
    condition     = length(var.dynamodb_tables) + length(var.s3_buckets) + length(var.kms_keys) >= 1
    error_message = "El rol debe dar acceso a algo: declara al menos una tabla (dynamodb_tables), un bucket (s3_buckets) o una clave (kms_keys)."
  }
}

variable "s3_buckets" {
  description = "Buckets S3 con un prefijo por tenant, por clave estable. El rol accede a <bucket>/<prefix><tenant>/* y solo puede listar ese prefijo. kms_key_arn (la CMK del bucket, con bucket key activada como en storage/s3-bucket) añade kms:Decrypt/GenerateDataKey limitados a S3 y a ese bucket. read_only limita a lecturas."
  type = map(object({
    bucket_arn  = string
    prefix      = optional(string, "")
    kms_key_arn = optional(string)
    read_only   = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for b in values(var.s3_buckets) : can(regex("^arn:aws[a-z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", b.bucket_arn))])
    error_message = "Cada bucket_arn debe ser el ARN de un bucket (arn:aws:s3:::<nombre>), sin objetos ni comodines."
  }

  validation {
    condition     = alltrue([for b in values(var.s3_buckets) : b.prefix == "" || can(regex("^[A-Za-z0-9!_.()'-]+(/[A-Za-z0-9!_.()'-]+)*/$", b.prefix))])
    error_message = "prefix debe ser vacío o terminar en / (p. ej. tenants/), sin comodines ni barra inicial."
  }

  validation {
    condition     = alltrue([for b in values(var.s3_buckets) : b.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/", b.kms_key_arn))])
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }
}

variable "kms_keys" {
  description = "CMKs para cifrado en la aplicación (envelope encryption por tenant), por clave estable. El rol solo puede cifrar y descifrar con el contexto de cifrado <tenant_tag_key> = <tenant de la sesión>, de modo que un tenant no descifra datos de otro aunque compartan clave."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for k in values(var.kms_keys) : can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/", k))])
    error_message = "Cada valor de kms_keys debe ser el ARN de una clave KMS (no un alias)."
  }
}

variable "permissions_boundary_arn" {
  description = "ARN de una permissions boundary opcional para el rol."
  type        = string
  default     = null

  validation {
    condition     = var.permissions_boundary_arn == null || can(regex("^arn:aws[a-z-]*:iam::([0-9]{12}|aws):policy/", var.permissions_boundary_arn))
    error_message = "permissions_boundary_arn debe ser el ARN de una política IAM."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
