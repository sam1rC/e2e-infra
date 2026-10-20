provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "alert_email" {
  description = "Correo que recibe las alarmas (debe confirmar la suscripción)."
  type        = string
  default     = "ops@example.com"
  nullable    = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "alarms"

  service_principals = ["cloudwatch.amazonaws.com", "sns.amazonaws.com"]
}

# Los recursos vigilados se identifican por nombre: en una composición real salen de las salidas de los
# módulos compute/ y data/ (alb_arn_suffix, cluster_id, replication_group_id, table_name...).
module "alarms" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  kms_key_arn = module.kms.key_arn

  email_subscriptions = [var.alert_email]

  alb = {
    web = {
      alb_arn_suffix          = "app/acme-dev-web/50dc6c495c0c9188"
      target_group_arn_suffix = "targetgroup/acme-dev-web/73e2d6bc24d8a067"
    }
  }

  ecs_services = {
    web = { cluster_name = "acme-dev", service_name = "acme-dev-web", min_running_tasks = 2 }
  }

  aurora_clusters = {
    main = { cluster_id = "acme-dev-aurora", has_replicas = true }
  }

  rds_instances = {
    reports = { instance_id = "acme-dev-postgres" }
  }

  elasticache = {
    sessions = { replication_group_id = "acme-dev-valkey", node_count = 2 }
  }

  dynamodb_tables = {
    orders = { table_name = "acme-dev-orders" }
  }

  lambda_functions = {
    worker = { function_name = "acme-dev-worker", timeout_seconds = 30 }
  }

  rest_apis = {
    public = { api_name = "acme-dev-api", stage = "v1" }
  }

  http_apis = {
    internal = { api_id = "a1b2c3d4e5" }
  }

  waf_web_acls = {
    regional = { web_acl_name = "acme-dev-web", region_dimension = "us-east-1" }
  }

  thresholds = {
    alb_target_5xx_count = 5
    db_connections       = 200
  }
}

output "topic_arn" {
  description = "ARN del topic de alarmas."
  value       = module.alarms.topic_arn
}

output "alarm_count" {
  description = "Número de alarmas creadas."
  value       = module.alarms.alarm_count
}
