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

variable "alert_emails" {
  description = "Correos que reciben las alertas de seguridad (GuardDuty severidad >= 7 y Security Hub CRITICAL/HIGH). Cada destinatario debe confirmar la suscripción SNS."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) >= 1 && alltrue([for e in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Indica al menos un correo válido en alert_emails."
  }

  nullable = false
}

variable "log_archive" {
  description = "Destino externo de logs (cuenta Log Archive en SaaS T1). Si es null, el módulo crea un bucket y una CMK locales. El bucket externo debe tener ya la política que permite escribir a CloudTrail y Config de esta cuenta, y su clave debe permitirles cifrar."
  type = object({
    bucket_name = string
    kms_key_arn = string
  })
  default = null
}

variable "log_retention_days" {
  description = "Días que se conservan los logs de CloudTrail y Config en el bucket local (también la retención del grupo de CloudWatch Logs de CloudTrail, ajustada al valor admitido más cercano)."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "log_retention_days debe ser al menos 90."
  }

  nullable = false
}

variable "cloudtrail" {
  description = "Opciones de CloudTrail. s3_data_events registra el acceso a objetos de todos los buckets (coste por evento)."
  type = object({
    s3_data_events = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "guardduty_features" {
  description = "Protecciones opcionales de GuardDuty."
  type = object({
    s3_data_events         = optional(bool, true)
    ebs_malware_protection = optional(bool, true)
    rds_login_events       = optional(bool, true)
    lambda_network_logs    = optional(bool, true)
    eks_audit_logs         = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "security_hub_standards" {
  description = "Estándares de Security Hub a suscribir. Verifica las versiones disponibles con `aws securityhub describe-standards` antes de cambiarlas."
  type = object({
    foundational     = optional(bool, true)
    foundational_ver = optional(string, "1.0.0")
    cis              = optional(bool, true)
    cis_ver          = optional(string, "5.0.0")
  })
  default  = {}
  nullable = false
}

variable "access_analyzer_type" {
  description = "Tipo de IAM Access Analyzer: ACCOUNT, u ORGANIZATION en la cuenta de seguridad delegada."
  type        = string
  default     = "ACCOUNT"

  validation {
    condition     = contains(["ACCOUNT", "ORGANIZATION"], var.access_analyzer_type)
    error_message = "access_analyzer_type debe ser ACCOUNT u ORGANIZATION."
  }

  nullable = false
}

variable "inspector_resource_types" {
  description = "Tipos de recurso que escanea Amazon Inspector v2."
  type        = list(string)
  default     = ["ECR", "LAMBDA"]

  validation {
    condition     = alltrue([for t in var.inspector_resource_types : contains(["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"], t)])
    error_message = "inspector_resource_types admite EC2, ECR, LAMBDA y LAMBDA_CODE."
  }

  nullable = false
}

variable "password_policy" {
  description = "Política de contraseñas IAM (por si existen usuarios humanos; lo recomendado es IAM Identity Center)."
  type = object({
    minimum_length  = optional(number, 14)
    max_age_days    = optional(number, 90)
    reuse_prevented = optional(number, 24)
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.password_policy.minimum_length >= 14
    error_message = "minimum_length debe ser al menos 14."
  }
}

variable "budget" {
  description = "Presupuesto mensual y detección de anomalías (módulo budgets). null = no se crea."
  type = object({
    monthly_limit_usd     = number
    alert_emails          = list(string)
    anomaly_threshold_usd = optional(number, 100)
  })
  default = null
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
