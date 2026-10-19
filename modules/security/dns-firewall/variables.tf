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
  description = "VPC cuyo tráfico DNS se filtra (el del resolvedor de Route 53 de la VPC, no el de resolvedores propios)."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id debe tener el formato vpc-xxxxxxxx."
  }

  nullable = false
}

variable "managed_domain_lists" {
  description = "Listas de dominios gestionadas por AWS, por clave estable (p. ej. malware, botnet, threats): domain_list_id (rslvr-fdl-..., distinto en cada región y obtenido con `aws route53resolver list-firewall-domain-lists --query \"FirewallDomainLists[?ManagedOwnerName!=null]\"`), priority (1-10000, única: se evalúan de menor a mayor), action (BLOCK por defecto, ALERT para solo registrar o ALLOW) y block_response (NXDOMAIN o NODATA). El plan recomienda AWSManagedDomainsMalwareDomainList, AWSManagedDomainsBotnetCommandandControl y AWSManagedDomainsAggregateThreatList en BLOCK, y en T1 también AWSManagedDomainsAmazonGuardDutyThreatList."
  type = map(object({
    domain_list_id = string
    priority       = number
    action         = optional(string, "BLOCK")
    block_response = optional(string, "NXDOMAIN")
  }))
  nullable = false

  validation {
    condition     = length(var.managed_domain_lists) >= 1
    error_message = "Indica al menos una lista de dominios."
  }

  validation {
    condition     = alltrue([for k in keys(var.managed_domain_lists) : can(regex("^[a-z][a-z0-9-]{0,29}$", k))])
    error_message = "Las claves deben ser minúsculas, dígitos y guiones (1-30 caracteres), empezando por letra."
  }

  validation {
    condition     = alltrue([for l in values(var.managed_domain_lists) : can(regex("^rslvr-fdl-[0-9a-f]{8,17}$", l.domain_list_id))])
    error_message = "domain_list_id debe tener el formato rslvr-fdl-xxxxxxxx."
  }

  validation {
    condition     = alltrue([for l in values(var.managed_domain_lists) : l.priority >= 1 && l.priority <= 10000]) && length(distinct([for l in values(var.managed_domain_lists) : l.priority])) == length(var.managed_domain_lists)
    error_message = "Las prioridades deben estar entre 1 y 10000 y no repetirse."
  }

  validation {
    condition     = alltrue([for l in values(var.managed_domain_lists) : contains(["ALLOW", "ALERT", "BLOCK"], l.action)])
    error_message = "action debe ser ALLOW, ALERT o BLOCK."
  }

  validation {
    condition     = alltrue([for l in values(var.managed_domain_lists) : contains(["NXDOMAIN", "NODATA"], l.block_response)])
    error_message = "block_response debe ser NXDOMAIN o NODATA."
  }
}

variable "query_log_destination_arn" {
  description = "ARN del bucket S3 (opcionalmente con prefijo: arn:aws:s3:::bucket/dns) donde se guardan los logs de consultas DNS. El bucket debe permitir la entrega de delivery.logs.amazonaws.com (s3:PutObject con bucket-owner-full-control y s3:GetBucketAcl, condicionados a aws:SourceAccount), igual que los flow logs; el bucket de logs de account-baseline no lo hace todavía."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9](/.*)?$", var.query_log_destination_arn))
    error_message = "query_log_destination_arn debe ser el ARN de un bucket S3 (con prefijo opcional)."
  }

  nullable = false
}

variable "association_priority" {
  description = "Prioridad del grupo de reglas en la VPC (101-9900) frente a otros grupos asociados (p. ej. los de Firewall Manager)."
  type        = number
  default     = 101

  validation {
    condition     = var.association_priority >= 101 && var.association_priority <= 9900
    error_message = "association_priority debe estar entre 101 y 9900."
  }

  nullable = false
}

variable "fail_open" {
  description = "Si el firewall no puede evaluar una consulta: true la deja pasar (prioriza disponibilidad) y false la rechaza (prioriza seguridad, el valor por defecto de AWS)."
  type        = bool
  default     = false
  nullable    = false
}

variable "mutation_protection" {
  description = "Impide desasociar el grupo de reglas de la VPC sin retirar antes la protección. null = activa en prod."
  type        = bool
  default     = null
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
