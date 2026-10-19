variable "project" {
  description = "Nombre del proyecto; prefijo de los nombres de políticas."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project debe ser minúsculas, dígitos y guiones (2-21 caracteres), empezando por letra."
  }

  nullable = false
}

variable "environment" {
  description = "Entorno al que aplican las políticas (p. ej. la OU Workloads/Prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "target_ids" {
  description = "IDs de OU (ou-...), raíz (r-...) o cuenta (12 dígitos) a los que se adjuntan las políticas. Cada destino admite como máximo 5 SCP incluida FullAWSAccess: este módulo usa 2."
  type        = list(string)

  validation {
    condition     = length(var.target_ids) >= 1 && alltrue([for t in var.target_ids : can(regex("^(r-[0-9a-z]{4,32}|ou-[0-9a-z]{4,32}-[0-9a-z]{8,32}|[0-9]{12})$", t))])
    error_message = "target_ids debe contener IDs válidos de raíz, OU o cuenta."
  }

  nullable = false
}

variable "admin_role_arns" {
  description = "ARNs (admiten comodines) de los roles exentos de las denegaciones: administración de la organización, Control Tower y el rol que aplica la línea base. Sin al menos uno, la organización podría quedar bloqueada."
  type        = list(string)

  validation {
    condition     = length(var.admin_role_arns) >= 1
    error_message = "Indica al menos un rol de administración exento (p. ej. arn:aws:iam::*:role/AWSControlTowerExecution)."
  }

  nullable = false
}

variable "allowed_regions" {
  description = "Regiones en las que se permite operar. Si usas WAF/ACM de CloudFront incluye us-east-1."
  type        = list(string)

  validation {
    condition     = length(var.allowed_regions) >= 1 && alltrue([for r in var.allowed_regions : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", r))])
    error_message = "allowed_regions debe contener al menos una región válida (p. ej. us-east-1)."
  }

  nullable = false
}

variable "global_service_actions" {
  description = "Acciones de servicios globales exentas de la restricción de región."
  type        = list(string)
  default = [
    "iam:*",
    "cloudfront:*",
    "route53:*",
    "route53domains:*",
    "waf:*",
    "sts:*",
    "organizations:*",
    "support:*",
    "budgets:*",
    "ce:*",
    "account:*",
    "billing:*",
    "cur:*",
    "health:*",
    "pricing:*",
    "shield:*",
    "trustedadvisor:*",
  ]
  nullable = false
}

variable "state_bucket_arns" {
  description = "ARNs de los buckets de estado a proteger (vacío = no se añade la protección)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "state_kms_key_arns" {
  description = "ARNs de las claves KMS de estado a proteger (vacío = no se añade la protección)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "ci_role_name_prefix" {
  description = "Prefijo de los roles de CI protegidos (<prefix>-plan-* y <prefix>-apply-*), como crea el módulo github-oidc."
  type        = string
  default     = "gha"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.ci_role_name_prefix))
    error_message = "ci_role_name_prefix debe ser minúsculas, dígitos y guiones (2-16 caracteres), empezando por letra."
  }

  nullable = false
}

variable "bootstrap_role_arns" {
  description = "ARNs de los roles que pueden modificar el estado y los roles de CI (bootstrap/break-glass). Si es vacío, usa admin_role_arns."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "enable_resource_control_policies" {
  description = "Crea además una RCP que exige TLS y limita S3/KMS/Secrets Manager/STS/SQS a principals de la organización. Requiere que RCP esté habilitado en la organización y organization_id."
  type        = bool
  default     = false
  nullable    = false
}

variable "organization_id" {
  description = "ID de la organización (o-xxxxxxxxxx). Obligatorio con enable_resource_control_policies."
  type        = string
  default     = null

  validation {
    condition     = var.organization_id == null || can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "organization_id debe tener el formato o-xxxxxxxxxx."
  }

  validation {
    condition     = !var.enable_resource_control_policies || var.organization_id != null
    error_message = "organization_id es obligatorio cuando enable_resource_control_policies = true."
  }
}

variable "tags" {
  description = "Etiquetas adicionales de las políticas."
  type        = map(string)
  default     = {}
  nullable    = false
}
