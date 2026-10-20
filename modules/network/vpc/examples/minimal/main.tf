provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.20.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  # Solo para el ejemplo mínimo: en un entorno real los flow logs se mantienen activos (ver examples/complete).
  enable_flow_logs = false
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.vpc.vpc_id
}
