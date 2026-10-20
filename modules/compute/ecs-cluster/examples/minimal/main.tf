provider "aws" {
  region = "us-east-1"
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
  kms_key_arn = module.kms.key_arn
}

output "cluster_name" {
  description = "Nombre del cluster."
  value       = module.cluster.cluster_name
}
