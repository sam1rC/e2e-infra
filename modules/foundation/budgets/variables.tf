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

variable "monthly_limit_usd" {
  description = "Presupuesto mensual de la cuenta, en USD."
  type        = number

  validation {
    condition     = var.monthly_limit_usd > 0
    error_message = "monthly_limit_usd debe ser mayor que 0."
  }

  nullable = false
}

variable "alert_emails" {
  description = "Correos que reciben las alertas de presupuesto y de anomalías de costo."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) >= 1 && alltrue([for e in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Indica al menos un correo válido en alert_emails."
  }

  nullable = false
}

variable "alert_thresholds_percent" {
  description = "Porcentajes del presupuesto (sobre el gasto real) que disparan una alerta. Además se alerta con el 100% previsto."
  type        = list(number)
  default     = [80, 100, 120]

  validation {
    condition     = length(var.alert_thresholds_percent) >= 1 && alltrue([for t in var.alert_thresholds_percent : t > 0 && t <= 1000])
    error_message = "Los umbrales deben estar entre 0 (exclusivo) y 1000."
  }

  nullable = false
}

variable "anomaly_threshold_usd" {
  description = "Impacto absoluto mínimo, en USD, para notificar una anomalía de costo."
  type        = number
  default     = 100

  validation {
    condition     = var.anomaly_threshold_usd > 0
    error_message = "anomaly_threshold_usd debe ser mayor que 0."
  }

  nullable = false
}

variable "existing_anomaly_monitor_arn" {
  description = "ARN de un monitor de anomalías por servicio que ya exista en la cuenta. AWS crea automáticamente \"Default-Services-Monitor\" en las cuentas nuevas y solo admite un monitor DIMENSIONAL/SERVICE por cuenta: en ese caso pasa su ARN (aws ce get-anomaly-monitors) y el módulo solo crea la suscripción. null = el módulo crea el monitor."
  type        = string
  default     = null

  validation {
    condition     = var.existing_anomaly_monitor_arn == null || can(regex("^arn:aws[a-z-]*:ce::[0-9]{12}:anomalymonitor/[0-9a-f-]+$", var.existing_anomaly_monitor_arn))
    error_message = "existing_anomaly_monitor_arn debe ser el ARN de un monitor de Cost Anomaly Detection (arn:aws:ce::<cuenta>:anomalymonitor/<id>)."
  }
}

variable "tags" {
  description = "Etiquetas adicionales."
  type        = map(string)
  default     = {}
  nullable    = false
}
