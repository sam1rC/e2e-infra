provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para el nombre del proyecto en pruebas (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "state_backend" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"

  object_lock_days                  = 1
  noncurrent_version_retention_days = 90

  tags = {
    Owner = "platform"
  }
}

output "backend_config" {
  description = "Bloque backend/encryption sugerido."
  value       = module.state_backend.backend_config
}

output "bucket_arn" {
  description = "ARN del bucket de estado."
  value       = module.state_backend.bucket_arn
}
