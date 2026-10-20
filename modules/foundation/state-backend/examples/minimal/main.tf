provider "aws" {
  region = "us-east-1"
}

module "state_backend" {
  source = "../.."

  project     = "acme"
  environment = "dev"
}

output "backend_config" {
  description = "Bloque backend/encryption sugerido."
  value       = module.state_backend.backend_config
}
