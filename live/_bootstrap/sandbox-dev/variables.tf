# Variables comunes de todas las raíces de live/ (valores en el *.auto.tfvars del directorio).

variable "account_id" {
  description = "Cuenta AWS donde se aplica esta raíz (allowed_account_ids del provider)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id debe tener 12 dígitos."
  }

  nullable = false
}

variable "region" {
  description = "Región principal de la cuenta."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.region))
    error_message = "region debe ser un código de región de AWS (p. ej. us-east-1)."
  }

  nullable = false
}

variable "assume_role_arn" {
  description = "Rol que asume el provider (p. ej. OrganizationAccountAccessRole al aplicar desde la cuenta de management). null = usar las credenciales del entorno (OIDC en CI, Identity Center en local)."
  type        = string
  default     = null
}

variable "project" {
  description = "Prefijo de nombres del cliente (minúsculas, dígitos y guiones)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "project debe ser minúsculas, dígitos y guiones (2-21 caracteres), empezando por letra."
  }

  nullable = false
}

variable "environment" {
  description = "Entorno (dev, staging o prod); también decide la clave del estado y los valores por defecto de las capas."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "blueprint" {
  description = "Blueprint del catálogo desplegado (etiqueta Blueprint)."
  type        = string
  nullable    = false
}

variable "owner" {
  description = "Equipo responsable (etiqueta Owner)."
  type        = string
  nullable    = false
}

variable "cost_center" {
  description = "Centro de coste (etiqueta CostCenter)."
  type        = string
  nullable    = false
}

variable "data_classification" {
  description = "Clasificación de los datos (etiqueta DataClassification)."
  type        = string

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification debe ser public, internal, confidential o restricted."
  }

  nullable = false
}

variable "tenant" {
  description = "Tenant dueño de todos los recursos de esta raíz (etiqueta Tenant, solo en cuentas silo). null = sin etiqueta."
  type        = string
  default     = null
}

variable "extra_tags" {
  description = "Etiquetas adicionales del cliente (no pueden sustituir a las obligatorias)."
  type        = map(string)
  default     = {}
  nullable    = false
}

# Variables propias del bootstrap.

variable "github_org" {
  description = "Organización (o usuario) de GitHub dueña del repositorio de infraestructura."
  type        = string
  nullable    = false
}

variable "github_repo" {
  description = "Repositorio de infraestructura del cliente (sin la organización)."
  type        = string
  nullable    = false
}

variable "github_subject_prefix" {
  description = "Prefijo del claim sub de OIDC del repositorio (sub_claim_prefix de `gh api repos/<org>/<repo>/actions/oidc/customization/sub`); los repositorios nuevos usan repo:<org>@<id>/<repo>@<id>. null = repo:<org>/<repo>."
  type        = string
  default     = null
}

variable "github_environment" {
  description = "GitHub Environment que autoriza el apply en esta cuenta (en prod, con revisores obligatorios)."
  type        = string
  nullable    = false
}

variable "create_oidc_provider" {
  description = "Crea el proveedor OIDC de GitHub (solo uno por cuenta: false en el segundo entorno de una cuenta compartida)."
  type        = bool
  nullable    = false
}

variable "artifacts_bucket" {
  description = "Crea el bucket de artefactos de Lambda <project>-<env>-artifacts-<cuenta> (T3 y control plane de SaaS T1)."
  type        = bool
  default     = false
  nullable    = false
}

variable "kms_admin_principal_arns" {
  description = "ARNs que administran la CMK de estado (sin permiso de uso), p. ej. el rol de administración de Identity Center."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "kms_user_principal_arns" {
  description = "ARNs humanos que usan la CMK de estado además de los roles de CI (operación break-glass)."
  type        = list(string)
  default     = []
  nullable    = false
}
