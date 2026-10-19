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
  description = "Entorno de despliegue. Determina el nombre de los roles, el prefijo de estado y el GitHub Environment que puede asumir el rol de apply."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser uno de: dev, staging, prod."
  }

  nullable = false
}

variable "github_org" {
  description = "Organización (o usuario) de GitHub propietaria del repositorio."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_org))
    error_message = "github_org solo admite letras, dígitos y guiones (sin comodines)."
  }

  nullable = false
}

variable "github_repo" {
  description = "Nombre del repositorio de GitHub (sin la organización)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,100}$", var.github_repo))
    error_message = "github_repo solo admite letras, dígitos, puntos, guiones y guiones bajos (sin comodines)."
  }

  nullable = false
}

variable "github_environment" {
  description = "Nombre del GitHub Environment que autoriza el apply. Si es null se usa el valor de environment."
  type        = string
  default     = null

  validation {
    condition     = var.github_environment == null || can(regex("^[A-Za-z0-9._-]{1,100}$", var.github_environment))
    error_message = "github_environment solo admite letras, dígitos, puntos, guiones y guiones bajos (sin comodines)."
  }
}

variable "main_branch" {
  description = "Rama principal desde la que el rol de plan puede ejecutarse además de los pull requests."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]{1,100}$", var.main_branch))
    error_message = "main_branch solo admite letras, dígitos, puntos, guiones, guiones bajos y barras (sin comodines)."
  }

  nullable = false
}

variable "create_provider" {
  description = "Crea el proveedor OIDC de GitHub. Ponlo en false si la cuenta ya tiene uno (solo puede haber uno por URL)."
  type        = bool
  default     = true
  nullable    = false
}

variable "name_prefix" {
  description = "Prefijo de los nombres de rol: <prefix>-plan-<env> y <prefix>-apply-<env>."
  type        = string
  default     = "gha"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix))
    error_message = "name_prefix debe ser minúsculas, dígitos y guiones (2-16 caracteres), empezando por letra."
  }

  nullable = false
}

variable "state_bucket_arn" {
  description = "ARN del bucket de estado (salida de state-backend)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:s3:::[a-z0-9.-]+$", var.state_bucket_arn))
    error_message = "state_bucket_arn debe ser el ARN de un bucket S3 (arn:<partition>:s3:::<bucket>)."
  }

  nullable = false
}

variable "state_kms_key_arn" {
  description = "ARN de la CMK de estado (salida de state-backend)."
  type        = string

  validation {
    condition     = can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/[0-9a-f-]+$", var.state_kms_key_arn))
    error_message = "state_kms_key_arn debe ser el ARN de una clave KMS (no un alias)."
  }

  nullable = false
}

variable "plan_policy_arns" {
  description = "Políticas gestionadas del rol de plan (solo lectura). Por defecto ReadOnlyAccess."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  nullable    = false
}

variable "apply_policy_arns" {
  description = "Políticas gestionadas del rol de apply. Por defecto AdministratorAccess, acotado por la permission boundary; en producción conviene sustituirlas por una política a medida de lo que despliega el entorno."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  nullable    = false
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
