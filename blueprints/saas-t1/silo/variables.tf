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


variable "tenant_id" {
  description = "Tenant premium dueño de esta cuenta (etiqueta Tenant, alias de la CMK y parámetro SSM). Las capas app-* del blueprint se despliegan después en esta misma cuenta."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,23}$", var.tenant_id))
    error_message = "tenant_id debe ser minúsculas, dígitos y guiones (2-24 caracteres), empezando por letra."
  }

  nullable = false
}

variable "deploy_role" {
  description = "Rol que asume el pipeline del control plane (GitHub Actions con OIDC en la cuenta de CI) para desplegar las capas del tenant: roles de confianza, políticas gestionadas y permissions boundary (obligatoria: el rol puede crear roles IAM). organization_id limita la confianza a la organización."
  type = object({
    trusted_role_arns        = list(string)
    managed_policy_arns      = optional(map(string), { admin = "arn:aws:iam::aws:policy/AdministratorAccess" })
    permissions_boundary_arn = string
    organization_id          = optional(string)
  })
  nullable = false
}

variable "budget" {
  description = "Presupuesto mensual de la cuenta del tenant (coste dedicado, base de la facturación del tier premium) y correos de aviso."
  type = object({
    monthly_limit_usd            = number
    alert_emails                 = list(string)
    existing_anomaly_monitor_arn = optional(string)
  })
  nullable = false
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos (las obligatorias van en default_tags del provider, en live/)."
  type        = map(string)
  default     = {}
  nullable    = false
}
