provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.85.0.0/16"
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

  service_principals = ["logs.us-east-1.amazonaws.com"]
  via_services = [
    "rds.us-east-1.amazonaws.com",
    "secretsmanager.us-east-1.amazonaws.com",
  ]
}

# Representa el SG de las tareas ECS de la capa app.
resource "aws_security_group" "app" {
  name        = "acme-${var.name_suffix}-app-example"
  description = "SG de aplicacion del ejemplo"
  vpc_id      = module.vpc.vpc_id
}

module "vpc_endpoints" {
  source = "../../../../network/vpc-endpoints"

  project         = "acme-${var.name_suffix}"
  environment     = "dev"
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.subnet_ids["app"]
  route_table_ids = module.vpc.route_table_ids["app"]

  interface_services = ["secretsmanager"]
  gateway_services   = []

  allowed_security_group_ids = {
    app      = aws_security_group.app.id
    rotation = module.rds.rotation_security_group_id
  }
}

module "rds" {
  source = "../.."

  project        = "acme-${var.name_suffix}"
  environment    = "dev"
  name           = "acme-${var.name_suffix}-postgres"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.subnet_ids["data"]
  kms_key_arn    = module.kms.key_arn
  engine_version = "17.11"

  allowed_security_group_ids = {
    app = aws_security_group.app.id
  }

  instance_class = "db.t4g.medium"
  multi_az       = true
  storage        = { allocated_gb = 20, max_allocated_gb = 50 }

  backup = {
    retention_days     = 7
    window             = "03:00-04:00"
    maintenance_window = "sun:05:00-sun:06:00"
  }
  backup_plan = "starter"

  database_insights_mode     = "standard"
  monitoring_interval        = 60
  log_retention_days         = 30
  log_min_duration_statement = 500

  deletion_protection = false
  skip_final_snapshot = true

  # Sandbox: el secreto se borra al momento con el destroy (no queda 7 días pendiente).
  app_secret_recovery_window_in_days = 0
  apply_immediately                  = true

  app_secret_rotation = {
    subnet_ids                 = module.vpc.subnet_ids["app"]
    endpoint_security_group_id = module.vpc_endpoints.security_group_id
  }

  publish_ssm_parameters = true
}

output "endpoint" {
  description = "Nombre DNS de la instancia."
  value       = module.rds.endpoint
}

output "app_secret_arn" {
  description = "ARN del secreto de la aplicación."
  value       = module.rds.app_secret_arn
}
