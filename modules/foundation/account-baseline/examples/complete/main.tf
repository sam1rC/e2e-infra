provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para el nombre del proyecto en pruebas (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

# Atención: la línea base es de cuenta (GuardDuty, Security Hub, Config, Access Analyzer,
# bloqueo de acceso público, EBS por defecto...). Aplícalo solo en una cuenta sandbox dedicada.
module "baseline" {
  source = "../.."

  project      = "acme-${var.name_suffix}"
  environment  = "prod"
  alert_emails = ["security@example.com", "customer@example.com"]

  log_retention_days = 400

  cloudtrail = {
    s3_data_events = true
  }

  guardduty_features = {
    eks_audit_logs = true
  }

  security_hub_standards = {
    cis = true
  }

  access_analyzer_type     = "ACCOUNT"
  inspector_resource_types = ["ECR", "LAMBDA", "LAMBDA_CODE"]

  password_policy = {
    minimum_length = 16
  }

  budget = {
    monthly_limit_usd     = 1500
    alert_emails          = ["finance@example.com"]
    anomaly_threshold_usd = 150
  }

  tags = {
    Owner = "platform"
  }
}

output "alerts_topic_arn" {
  description = "Tópico SNS de alertas de seguridad."
  value       = module.baseline.alerts_topic_arn
}

output "log_bucket_name" {
  description = "Bucket de logs de seguridad."
  value       = module.baseline.log_bucket_name
}
