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

variable "cidr_block" {
  description = "CIDR IPv4 de la VPC (entre /16 y /20)."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.cidr_block)) && tonumber(split("/", var.cidr_block)[1]) >= 16 && tonumber(split("/", var.cidr_block)[1]) <= 20
    error_message = "cidr_block debe ser un CIDR IPv4 válido entre /16 y /20."
  }

  nullable = false
}

variable "az_names" {
  description = "Zonas de disponibilidad (2 o 3), explícitas para que las claves de for_each sean estables. El CIDR de cada subred depende de la posición de su AZ: añade o quita AZ solo por el final de la lista."
  type        = list(string)

  validation {
    condition     = length(var.az_names) >= 2 && length(var.az_names) <= 3
    error_message = "az_names debe tener 2 o 3 zonas de disponibilidad."
  }

  validation {
    condition     = length(distinct(var.az_names)) == length(var.az_names)
    error_message = "az_names no puede contener duplicados."
  }

  nullable = false
}

variable "subnet_tiers" {
  description = "Capas de subredes a crear. La capa public solo se necesita para NAT zonal; con NAT regional o sin NAT no hace falta."
  type = object({
    public = optional(bool, false)
    app    = optional(bool, true)
    data   = optional(bool, true)
  })
  default  = {}
  nullable = false

  validation {
    condition     = startswith(var.nat_mode, "zonal") ? var.subnet_tiers.public : true
    error_message = "nat_mode zonal_single/zonal_per_az exige subnet_tiers.public = true (la NAT zonal vive en una subred pública)."
  }

  validation {
    condition     = var.nat_mode == "none" || var.subnet_tiers.app
    error_message = "Con NAT (nat_mode distinto de none) debe existir la capa app, que es la que enruta a la NAT."
  }

  validation {
    condition     = var.subnet_tiers.public || var.subnet_tiers.app || var.subnet_tiers.data
    error_message = "Al menos una capa de subredes debe estar activada."
  }
}

variable "subnet_newbits" {
  description = "Bits adicionales sobre el CIDR de la VPC para calcular cada subred con cidrsubnet (4 sobre un /16 da subredes /20)."
  type        = number
  default     = 4

  validation {
    condition     = var.subnet_newbits >= 4 && var.subnet_newbits <= 8
    error_message = "subnet_newbits debe estar entre 4 (caben los desplazamientos fijos por capa) y 8."
  }

  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) + var.subnet_newbits <= 28
    error_message = "El CIDR de las subredes resultante sería menor que /28."
  }

  nullable = false
}

variable "nat_mode" {
  description = "Salida a Internet de la capa app: none, zonal_single (una NAT), zonal_per_az (una por AZ) o regional (una NAT regional, sin subredes públicas)."
  type        = string
  default     = "regional"

  validation {
    condition     = contains(["none", "zonal_single", "zonal_per_az", "regional"], var.nat_mode)
    error_message = "nat_mode debe ser none, zonal_single, zonal_per_az o regional."
  }

  nullable = false
}

variable "create_internet_gateway" {
  description = "Crea y asocia un Internet Gateway. Es obligatorio con NAT regional o subredes públicas y lo exigen los VPC origins de CloudFront aunque no haya subredes públicas."
  type        = bool
  default     = true

  validation {
    condition     = var.create_internet_gateway || (var.nat_mode != "regional" && !var.subnet_tiers.public)
    error_message = "NAT regional y la capa pública requieren create_internet_gateway = true."
  }

  nullable = false
}

# El plan la exige solo para documentar la decisión; la validación la fuerza a false.
# tflint-ignore: terraform_unused_declarations
variable "data_subnet_internet_route" {
  description = "Solo documenta la decisión de diseño: las subredes data nunca tienen ruta por defecto a Internet. Debe ser false."
  type        = bool
  default     = false

  validation {
    condition     = var.data_subnet_internet_route == false
    error_message = "Las subredes data no pueden tener ruta a Internet: data_subnet_internet_route debe ser false."
  }

  nullable = false
}

variable "data_tier_ports" {
  description = "Puertos TCP que la NACL de la capa data admite desde las subredes app (PostgreSQL y Valkey por defecto)."
  type        = list(number)
  default     = [5432, 6379]

  validation {
    condition     = length(var.data_tier_ports) >= 1 && length(var.data_tier_ports) <= 9 && alltrue([for p in var.data_tier_ports : p >= 1 && p <= 65535])
    error_message = "data_tier_ports debe tener entre 1 y 9 puertos válidos."
  }

  nullable = false
}

variable "enable_flow_logs" {
  description = "Activa los VPC Flow Logs hacia S3. Desactívalo solo de forma explícita (p. ej. dev efímero)."
  type        = bool
  default     = true
  nullable    = false
}

variable "flow_logs" {
  description = "Destino y formato de los flow logs. El bucket (con SSE-KMS) debe permitir la entrega de delivery.logs.amazonaws.com. Obligatorio si enable_flow_logs = true."
  type = object({
    s3_bucket_arn            = string
    traffic_type             = optional(string, "ALL")
    max_aggregation_interval = optional(number, 600)
    log_format               = optional(string)
  })
  default = null

  validation {
    condition     = !var.enable_flow_logs || var.flow_logs != null
    error_message = "Indica flow_logs.s3_bucket_arn o pon enable_flow_logs = false."
  }

  validation {
    condition     = var.flow_logs == null || contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs.traffic_type)
    error_message = "flow_logs.traffic_type debe ser ALL, ACCEPT o REJECT."
  }

  validation {
    condition     = var.flow_logs == null || contains([60, 600], var.flow_logs.max_aggregation_interval)
    error_message = "flow_logs.max_aggregation_interval debe ser 60 o 600."
  }
}

variable "alarm_actions" {
  description = "ARNs (p. ej. tópico SNS) notificados por la alarma ErrorPortAllocation de la NAT."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "publish_ssm_parameters" {
  description = "Publica los IDs de la red en SSM Parameter Store bajo /<project>/<env>/network/ para las capas consumidoras."
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
