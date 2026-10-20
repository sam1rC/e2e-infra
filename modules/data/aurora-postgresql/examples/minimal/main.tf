provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.82.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode               = "none"
  enable_flow_logs       = false # solo para el ejemplo
  publish_ssm_parameters = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "data"

  service_principals = ["logs.us-east-1.amazonaws.com"]
  via_services = [
    "rds.us-east-1.amazonaws.com",
    "secretsmanager.us-east-1.amazonaws.com",
  ]
}

# Una instancia de desarrollo; en prod se exigen 2 instancias y rotación del secreto de la aplicación.
module "aurora" {
  source = "../.."

  project        = "acme"
  environment    = "dev"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.subnet_ids["data"]
  kms_key_arn    = module.kms.key_arn
  engine_version = "17.11"

  publish_ssm_parameters = false
}

output "writer_endpoint" {
  description = "Endpoint del writer."
  value       = module.aurora.writer_endpoint
}
