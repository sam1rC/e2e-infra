provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "ecs"

  service_principals = ["logs.us-east-1.amazonaws.com"]
}

module "cluster" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  name        = "acme-dev-${var.name_suffix}"
  kms_key_arn = module.kms.key_arn

  container_insights  = "enhanced"
  enable_exec         = true
  enable_fargate_spot = true
  fargate_spot_weight = 4
  log_retention_days  = 30
}

output "cluster_name" {
  description = "Nombre del cluster."
  value       = module.cluster.cluster_name
}

output "capacity_providers" {
  description = "Capacity providers habilitados."
  value       = module.cluster.capacity_providers
}
