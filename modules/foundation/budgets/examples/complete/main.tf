provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para el nombre del proyecto en pruebas (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "existing_anomaly_monitor_arn" {
  description = "ARN del monitor de anomalías por servicio que AWS crea por defecto en la cuenta (Default-Services-Monitor). null = crear uno."
  type        = string
  default     = null
}

module "budgets" {
  source = "../.."

  project           = "acme-${var.name_suffix}"
  environment       = "prod"
  monthly_limit_usd = 5000
  alert_emails      = ["team@example.com", "customer@example.com"]

  alert_thresholds_percent = [50, 80, 100, 120]
  anomaly_threshold_usd    = 250

  existing_anomaly_monitor_arn = var.existing_anomaly_monitor_arn

  tags = {
    Owner = "platform"
  }
}

output "budget_name" {
  description = "Nombre del presupuesto."
  value       = module.budgets.budget_name
}
