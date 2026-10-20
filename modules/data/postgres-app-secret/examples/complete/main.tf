provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "master_secret_arn" {
  description = "ARN del secreto maestro gestionado por RDS de una base de datos PostgreSQL existente en la VPC de data. En una composición real sale del módulo aurora-postgresql o rds-postgresql."
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds!cluster-11111111-2222-3333-4444-555555555555-AbCdEf"
  nullable    = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.81.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode               = "none"
  enable_flow_logs       = false # solo para el ejemplo
  publish_ssm_parameters = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "data"

  via_services = ["secretsmanager.us-east-1.amazonaws.com"]
}

resource "aws_security_group" "db" {
  name        = "acme-${var.name_suffix}-db-example"
  description = "SG de base de datos del ejemplo"
  vpc_id      = module.vpc.vpc_id
}

# La función de rotación vive en la capa app y llega a Secrets Manager por el endpoint de interfaz,
# que a su vez la autoriza por su security group.
module "vpc_endpoints" {
  source = "../../../../network/vpc-endpoints"

  project        = "acme-${var.name_suffix}"
  environment    = "dev"
  vpc_id         = module.vpc.vpc_id
  vpc_cidr_block = module.vpc.vpc_cidr_block
  subnet_ids     = module.vpc.subnet_ids["app"]
  route_table_ids = concat(
    module.vpc.route_table_ids["app"],
    module.vpc.route_table_ids["data"],
  )

  interface_services = ["secretsmanager"]
  gateway_services   = []

  allowed_security_group_ids = {
    rotation = module.app_secret.rotation_security_group_id
  }
}

module "app_secret" {
  source = "../.."

  environment          = "dev"
  name                 = "acme-${var.name_suffix}-aurora"
  vpc_id               = module.vpc.vpc_id
  db_security_group_id = aws_security_group.db.id
  db_port              = 5432
  kms_key_arn          = module.kms.key_arn
  master_secret_arn    = var.master_secret_arn

  rotation = {
    subnet_ids                 = module.vpc.subnet_ids["app"]
    endpoint_security_group_id = module.vpc_endpoints.security_group_id
    automatically_after_days   = 30
  }

  # Sandbox: borrado inmediato con el destroy (0 solo se admite fuera de prod).
  recovery_window_in_days = 0
}

output "secret_arn" {
  description = "ARN del secreto de la aplicación."
  value       = module.app_secret.secret_arn
}

output "rotation_lambda_arn" {
  description = "ARN de la función de rotación."
  value       = module.app_secret.rotation_lambda_arn
}
