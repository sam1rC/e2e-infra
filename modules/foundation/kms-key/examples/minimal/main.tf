provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  purpose     = "data"
}

output "key_arn" {
  description = "ARN de la clave."
  value       = module.kms.key_arn
}
