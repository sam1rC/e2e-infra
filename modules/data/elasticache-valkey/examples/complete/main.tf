provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "ex"
  nullable    = false
}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.87.0.0/16"
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
  via_services       = ["elasticache.us-east-1.amazonaws.com"]
}

# Representa el SG de las tareas ECS de la capa app.
resource "aws_security_group" "app" {
  name        = "acme-${var.name_suffix}-app-example"
  description = "SG de aplicacion del ejemplo"
  vpc_id      = module.vpc.vpc_id
}

module "valkey" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "acme-${var.name_suffix}-valkey"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.subnet_ids["data"]
  kms_key_arn = module.kms.key_arn

  allowed_security_group_ids = {
    app = aws_security_group.app.id
  }

  engine_version     = "8.2"
  node_type          = "cache.t4g.small"
  num_cache_clusters = 2
  maxmemory_policy   = "allkeys-lru"

  # Un usuario de lectura/escritura y otro solo de lectura para un worker de informes.
  iam_users = {
    app    = {}
    report = { access_string = "on ~* +@read -@dangerous" }
  }

  snapshots = {
    retention_days     = 3
    window             = "03:00-04:00"
    maintenance_window = "sun:05:00-sun:06:00"
  }
  final_snapshot_enabled = false
  log_retention_days     = 30
  apply_immediately      = true

  publish_ssm_parameters = true
}

output "primary_endpoint" {
  description = "Endpoint del nodo primario."
  value       = module.valkey.primary_endpoint
}

output "iam_connect_resource_arns" {
  description = "ARNs para elasticache:Connect por usuario."
  value       = module.valkey.iam_connect_resource_arns
}
