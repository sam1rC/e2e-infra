provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.86.0.0/16"
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
  via_services       = ["elasticache.us-east-1.amazonaws.com"]
}

# Un nodo de desarrollo; en prod se exigen 2 nodos (failover automático y Multi-AZ).
module "valkey" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.subnet_ids["data"]
  kms_key_arn = module.kms.key_arn

  publish_ssm_parameters = false
}

output "primary_endpoint" {
  description = "Endpoint del nodo primario."
  value       = module.valkey.primary_endpoint
}
