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
  description = "Nombre lógico de la tabla; el nombre real es <project>-<environment>-<name>."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.name))
    error_message = "name debe ser minúsculas, dígitos y guiones (2-41 caracteres), empezando por letra."
  }

  nullable = false
}

variable "kms_key_arn" {
  description = "ARN de la CMK del entorno que cifra la tabla (SSE con clave propia, no la gestionada por AWS). Su política debe autorizar a DynamoDB vía kms:ViaService."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/", var.kms_key_arn))
    error_message = "kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "attributes" {
  description = "Atributos clave de la tabla y de sus índices, como mapa nombre => tipo (S, N o B). Solo los que se usan como clave: DynamoDB rechaza atributos declarados que no estén en ninguna clave."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for t in values(var.attributes) : contains(["S", "N", "B"], t)])
    error_message = "El tipo de cada atributo debe ser S, N o B."
  }

  validation {
    condition     = contains(keys(var.attributes), var.hash_key) && (var.range_key == null || contains(keys(var.attributes), var.range_key))
    error_message = "hash_key y range_key deben estar declarados en attributes."
  }

  validation {
    condition = alltrue([
      for g in values(var.global_secondary_indexes) :
      contains(keys(var.attributes), g.hash_key) && (g.range_key == null || contains(keys(var.attributes), g.range_key))
    ])
    error_message = "Las claves de cada índice global deben estar declaradas en attributes."
  }

  validation {
    condition = alltrue([
      for l in values(var.local_secondary_indexes) : contains(keys(var.attributes), l.range_key)
    ])
    error_message = "La clave de ordenación de cada índice local debe estar declarada en attributes."
  }

  validation {
    condition = toset(keys(var.attributes)) == toset(concat(
      [var.hash_key],
      var.range_key == null ? [] : [var.range_key],
      flatten([for g in values(var.global_secondary_indexes) : concat([g.hash_key], g.range_key == null ? [] : [g.range_key])]),
      [for l in values(var.local_secondary_indexes) : l.range_key],
    ))
    error_message = "attributes solo puede contener atributos que sean clave de la tabla o de algún índice."
  }
}

variable "hash_key" {
  description = "Clave de partición de la tabla."
  type        = string
  nullable    = false
}

variable "range_key" {
  description = "Clave de ordenación de la tabla (opcional)."
  type        = string
  default     = null
}

variable "tenant_partition_key" {
  description = "Tabla multi-tenant con aislamiento por partición: exige que hash_key sea tenant_id, de modo que las políticas IAM con dynamodb:LeadingKeys (fase 8.3) puedan limitar a cada tenant a sus filas."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.tenant_partition_key || var.hash_key == "tenant_id"
    error_message = "Con tenant_partition_key = true, hash_key debe llamarse tenant_id."
  }
}

variable "global_secondary_indexes" {
  description = "Índices secundarios globales por nombre estable. Por defecto proyectan todos los atributos; con INCLUDE indica non_key_attributes. En modo PROVISIONED heredan la capacidad de la tabla."
  type = map(object({
    hash_key           = string
    range_key          = optional(string)
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for g in values(var.global_secondary_indexes) : contains(["ALL", "KEYS_ONLY", "INCLUDE"], g.projection_type)])
    error_message = "projection_type debe ser ALL, KEYS_ONLY o INCLUDE."
  }

  validation {
    condition     = alltrue([for g in values(var.global_secondary_indexes) : (g.projection_type == "INCLUDE") == (length(g.non_key_attributes) > 0)])
    error_message = "non_key_attributes es obligatorio con INCLUDE y no se admite con otra proyección."
  }

  validation {
    condition     = length(var.global_secondary_indexes) <= 20
    error_message = "DynamoDB admite como máximo 20 índices secundarios globales."
  }
}

variable "local_secondary_indexes" {
  description = "Índices secundarios locales por nombre estable (misma clave de partición, otra de ordenación). Solo pueden definirse al crear la tabla; exigen range_key."
  type = map(object({
    range_key          = string
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition     = length(var.local_secondary_indexes) == 0 || var.range_key != null
    error_message = "Los índices locales exigen que la tabla tenga range_key."
  }

  validation {
    condition     = alltrue([for l in values(var.local_secondary_indexes) : contains(["ALL", "KEYS_ONLY", "INCLUDE"], l.projection_type)])
    error_message = "projection_type debe ser ALL, KEYS_ONLY o INCLUDE."
  }

  validation {
    condition     = alltrue([for l in values(var.local_secondary_indexes) : (l.projection_type == "INCLUDE") == (length(l.non_key_attributes) > 0)])
    error_message = "non_key_attributes es obligatorio con INCLUDE y no se admite con otra proyección."
  }

  validation {
    condition     = length(var.local_secondary_indexes) <= 5
    error_message = "DynamoDB admite como máximo 5 índices secundarios locales."
  }
}

variable "billing_mode" {
  description = "PAY_PER_REQUEST (por defecto: sin planificar capacidad) o PROVISIONED (usa provisioned_capacity)."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode debe ser PAY_PER_REQUEST o PROVISIONED."
  }

  nullable = false
}

variable "provisioned_capacity" {
  description = "Capacidad de lectura y escritura en modo PROVISIONED (la heredan los índices globales). Obligatoria con PROVISIONED y no permitida con PAY_PER_REQUEST. Sin autoescalado: para tráfico variable, usa PAY_PER_REQUEST."
  type = object({
    read  = number
    write = number
  })
  default = null

  validation {
    condition     = (var.billing_mode == "PROVISIONED") == (var.provisioned_capacity != null)
    error_message = "provisioned_capacity es obligatoria con PROVISIONED y no se admite con PAY_PER_REQUEST."
  }

  validation {
    condition     = var.provisioned_capacity == null || (var.provisioned_capacity.read >= 1 && var.provisioned_capacity.write >= 1)
    error_message = "provisioned_capacity.read y write deben ser al menos 1."
  }
}

variable "table_class" {
  description = "STANDARD o STANDARD_INFREQUENT_ACCESS (almacenamiento más barato para tablas de acceso poco frecuente)."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table_class)
    error_message = "table_class debe ser STANDARD o STANDARD_INFREQUENT_ACCESS."
  }

  nullable = false
}

variable "point_in_time_recovery_days" {
  description = "Ventana de recuperación a un punto en el tiempo (1-35 días; PITR siempre activo). null = 35 en prod y 7 en el resto."
  type        = number
  default     = null

  validation {
    condition     = var.point_in_time_recovery_days == null || (var.point_in_time_recovery_days >= 1 && var.point_in_time_recovery_days <= 35)
    error_message = "point_in_time_recovery_days debe estar entre 1 y 35."
  }

  validation {
    condition     = var.environment != "prod" || coalesce(var.point_in_time_recovery_days, 35) >= 14
    error_message = "En prod la ventana de PITR debe ser de al menos 14 días."
  }
}

variable "deletion_protection" {
  description = "Protección contra borrado. null = true en prod y en staging, false en dev. En prod no puede desactivarse."
  type        = bool
  default     = null

  validation {
    condition     = var.environment != "prod" || var.deletion_protection != false
    error_message = "En prod deletion_protection no puede ser false."
  }
}

variable "ttl_attribute" {
  description = "Atributo con la fecha de expiración (epoch en segundos) para el TTL. null = sin TTL."
  type        = string
  default     = null

  validation {
    condition     = var.ttl_attribute == null || can(regex("^[A-Za-z_][A-Za-z0-9_]{0,254}$", var.ttl_attribute))
    error_message = "ttl_attribute debe ser un nombre de atributo válido."
  }
}

variable "stream_view_type" {
  description = "Activa DynamoDB Streams con este contenido: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE o NEW_AND_OLD_IMAGES. null = sin streams."
  type        = string
  default     = null

  validation {
    condition     = var.stream_view_type == null || contains(["KEYS_ONLY", "NEW_IMAGE", "OLD_IMAGE", "NEW_AND_OLD_IMAGES"], var.stream_view_type)
    error_message = "stream_view_type debe ser KEYS_ONLY, NEW_IMAGE, OLD_IMAGE o NEW_AND_OLD_IMAGES."
  }
}

variable "enable_contributor_insights" {
  description = "Activa CloudWatch Contributor Insights en la tabla (claves más usadas y más limitadas). Tiene coste por evento."
  type        = bool
  default     = false
  nullable    = false
}

variable "publish_ssm_parameters" {
  description = "Publica el nombre y los ARN en SSM Parameter Store bajo /<project>/<env>/data/dynamodb/<name>/ para las capas consumidoras."
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
