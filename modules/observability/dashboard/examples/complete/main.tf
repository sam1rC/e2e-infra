provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "alarms"

  service_principals = ["cloudwatch.amazonaws.com", "sns.amazonaws.com"]
}

# Las mismas identidades alimentan las alarmas y el dashboard; en una composición real salen de las
# salidas de los módulos compute/ y data/.
locals {
  alb             = { web = { alb_arn_suffix = "app/acme-dev-web/50dc6c495c0c9188", target_group_arn_suffix = "targetgroup/acme-dev-web/73e2d6bc24d8a067" } }
  ecs_services    = { web = { cluster_name = "acme-dev", service_name = "acme-dev-web" } }
  aurora_clusters = { main = { cluster_id = "acme-dev-aurora" } }
  dynamodb_tables = { orders = { table_name = "acme-dev-orders" } }
}

module "alarms" {
  source = "../../../alarms"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  kms_key_arn = module.kms.key_arn

  alb             = local.alb
  ecs_services    = { for k, s in local.ecs_services : k => merge(s, { min_running_tasks = 2 }) }
  aurora_clusters = { for k, c in local.aurora_clusters : k => merge(c, { has_replicas = true }) }
  dynamodb_tables = local.dynamodb_tables
}

module "dashboard" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "acme-${var.name_suffix}-ecommerce-t1"

  alarm_arns = module.alarms.alarm_arns

  # Service y Environment tal como aparecen en CloudWatch Application Signals (sidecar ADOT).
  application_signals = { service_name = "acme-dev-web", environment_name = "ecs:acme-dev" }

  alb             = local.alb
  ecs_services    = local.ecs_services
  aurora_clusters = local.aurora_clusters
  dynamodb_tables = local.dynamodb_tables

  rds_instances = {
    reports = { instance_id = "acme-dev-postgres" }
  }

  elasticache = {
    sessions = { replication_group_id = "acme-dev-valkey", node_count = 2 }
  }

  lambda_functions = {
    worker = { function_name = "acme-dev-worker" }
  }

  rest_apis = {
    public = { api_name = "acme-dev-api", stage = "v1" }
  }

  http_apis = {
    internal = { api_id = "a1b2c3d4e5" }
  }

  cloudfront_distributions = {
    site = { distribution_id = "E1ABCDEFGHIJKL" }
  }

  waf_web_acls = {
    edge = { web_acl_name = "acme-dev-edge" }
  }
}

output "dashboard_name" {
  description = "Nombre del dashboard."
  value       = module.dashboard.dashboard_name
}

output "widget_count" {
  description = "Número de widgets."
  value       = module.dashboard.widget_count
}
