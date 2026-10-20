provider "aws" {
  region = "us-east-1"
}

module "security_headers" {
  source = "../.."

  project     = "acme"
  environment = "dev"
}

output "policy_id" {
  description = "ID de la policy."
  value       = module.security_headers.policy_id
}
