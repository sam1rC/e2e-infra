provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para el nombre del proyecto en pruebas (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "security_headers" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "prod"

  hsts_max_age_seconds    = 63072000
  content_security_policy = "default-src 'self'; img-src 'self' data:; frame-ancestors 'none'"
}

output "policy_id" {
  description = "ID de la policy."
  value       = module.security_headers.policy_id
}
