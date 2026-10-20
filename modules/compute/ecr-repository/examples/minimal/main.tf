provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "ecr"
}

module "ecr" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  name        = "web"
  kms_key_arn = module.kms.key_arn
}

output "repository_url" {
  description = "URL del repositorio."
  value       = module.ecr.repository_url
}
