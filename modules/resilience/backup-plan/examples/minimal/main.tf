provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "backup"

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.us-east-1.amazonaws.com"]
}

# Plan diario, mensual y continuo para todo recurso etiquetado BackupPlan = starter.
module "backup" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  kms_key_arn = module.kms.key_arn
  tier        = "starter"

  publish_ssm_parameters = false
}

output "vault_arn" {
  description = "ARN del vault."
  value       = module.backup.vault_arn
}
