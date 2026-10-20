provider "aws" {
  region = "us-east-1"
}

# DNS fuera de Route 53: el certificado queda pendiente y los registros salen en validation_records.
module "certificate" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  domain_name = "app.example.com"
}

output "validation_records" {
  description = "Registros DNS a crear manualmente."
  value       = module.certificate.validation_records
}
