provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme"
  environment = "dev"
  cidr_block  = "10.80.0.0/16"
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

  via_services = ["secretsmanager.us-east-1.amazonaws.com"]
}

# En una composición real este SG lo crea el módulo de la base de datos.
resource "aws_security_group" "db" {
  name        = "acme-dev-db-example"
  description = "SG de base de datos del ejemplo"
  vpc_id      = module.vpc.vpc_id
}

# Sin rotación (solo permitido fuera de prod): crea únicamente el secreto vacío.
module "app_secret" {
  source = "../.."

  environment          = "dev"
  name                 = "acme-dev-aurora"
  vpc_id               = module.vpc.vpc_id
  db_security_group_id = aws_security_group.db.id
  kms_key_arn          = module.kms.key_arn
}

output "secret_arn" {
  description = "ARN del secreto de la aplicación."
  value       = module.app_secret.secret_arn
}
