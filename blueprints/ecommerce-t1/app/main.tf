module "ecr" {
  source = "../../../modules/compute/ecr-repository"

  project      = var.project
  environment  = var.environment
  name         = "app"
  kms_key_arn  = local.platform_key
  force_delete = !local.prod

  tags = var.tags
}

module "cluster" {
  source = "../../../modules/compute/ecs-cluster"

  project     = var.project
  environment = var.environment
  kms_key_arn = local.platform_key

  # enhanced añade métricas por tarea y contenedor (más caras): solo en prod.
  container_insights = local.prod ? "enhanced" : "enabled"
  log_retention_days = local.log_retention_days

  tags = var.tags
}

# Certificado REGIONAL del dominio público en el listener del ALB: CloudFront reenvía el Host del visitante
# y valida este certificado con https-only (ADR 0007). Vive en esta capa porque el ALB lo necesita antes
# de que exista la capa edge.
module "alb_certificate" {
  source = "../../../modules/edge/acm-certificate"
  count  = var.alb_certificate_arn == null ? 1 : 0

  project             = var.project
  environment         = var.environment
  domain_name         = var.domain_name
  zone_id             = var.zone_id
  wait_for_validation = true

  tags = var.tags
}

module "alb" {
  source = "../../../modules/compute/alb-internal"

  project         = var.project
  environment     = var.environment
  vpc_id          = local.vpc_id
  subnet_ids      = local.app_subnet_ids
  certificate_arn = local.alb_certificate_arn

  target_groups = {
    app = {
      port         = var.service.container_port
      health_check = { path = var.service.health_check_path }
    }
  }

  # Solo el dominio público llega a la app; el resto (DNS interno del ALB, otros Host) recibe el 404 por defecto.
  listener_rules = {
    app = { priority = 10, target_group = "app", host_headers = [var.domain_name] }
  }

  egress_targets = {
    app = { security_group_id = module.service.security_group_id, port = var.service.container_port }
  }

  access_logs_bucket_name = local.network["logs_bucket_name"]

  tags = var.tags
}

module "service" {
  source = "../../../modules/compute/ecs-service"

  project          = var.project
  environment      = var.environment
  name             = "app"
  cluster_arn      = module.cluster.cluster_arn
  vpc_id           = local.vpc_id
  subnet_ids       = local.app_subnet_ids
  image            = var.service.image
  command          = var.service.command
  container_port   = var.service.container_port
  cpu              = var.service.cpu
  memory           = var.service.memory
  cpu_architecture = var.service.cpu_architecture

  environment_variables = merge(var.service.environment_variables, var.extra_environment_variables, local.app_environment)

  # Usuario app_runtime (nunca el maestro): JSON con username/password que rota Secrets Manager.
  secrets              = { DB_CREDENTIALS = local.data["aurora/app_secret_arn"] }
  secrets_kms_key_arns = [local.data["kms_key_arn"]]

  log_kms_key_arn    = local.platform_key
  log_retention_days = local.log_retention_days

  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arns["app"]
  alb_enabled           = true # el ALB se crea en este mismo apply
  egress_rules          = local.egress_rules
  task_role_policies    = local.task_role_policies

  # ADOT: trazas OTLP a X-Ray/Application Signals por el endpoint xray (sin SDK ni daemon de X-Ray).
  enable_otel_sidecar = local.otel_enabled
  otel_image          = var.service.otel_image

  min_tasks               = var.service.min_tasks
  max_tasks               = var.service.max_tasks
  enable_exec             = !local.prod
  app_deploys_outside_iac = var.service.app_deploys_outside_iac

  volume_permissions_image = var.service.volume_permissions_image

  tags = var.tags
}

# Reglas que la capa consumidora añade a los SG de las capas anteriores (ADR 0016).
resource "aws_vpc_security_group_ingress_rule" "db_from_service" {
  security_group_id            = local.db_sg
  referenced_security_group_id = module.service.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = local.db_port
  to_port                      = local.db_port
  description                  = "PostgreSQL desde las tareas de la aplicacion"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_service" {
  count = local.cache_enabled ? 1 : 0

  security_group_id            = local.data["valkey/security_group_id"]
  referenced_security_group_id = module.service.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(local.data["valkey/port"])
  to_port                      = tonumber(local.data["valkey/port"])
  description                  = "Valkey desde las tareas de la aplicacion"

  tags = var.tags
}

# Eventos de dominio (orders.*) → Firehose → data lake en S3, particionado por fecha.
module "data_lake" {
  source = "../../../modules/storage/s3-bucket"

  project       = var.project
  environment   = var.environment
  purpose       = "data"
  bucket_name   = "${local.name}-data-lake-${local.account_id}"
  kms_key_arn   = local.platform_key
  force_destroy = !local.prod

  lifecycle_config = {
    transition_to_ia_days      = 30
    transition_to_glacier_days = 180
  }

  tags = var.tags
}

module "firehose" {
  source = "../../../modules/integration/firehose-to-s3"

  project            = var.project
  environment        = var.environment
  name               = "events"
  bucket_arn         = module.data_lake.bucket_arn
  kms_key_arn        = local.platform_key
  log_retention_days = local.log_retention_days

  tags = var.tags
}

module "events" {
  source = "../../../modules/integration/eventbridge-bus"

  project                = var.project
  environment            = var.environment
  kms_key_arn            = local.platform_key
  archive_retention_days = coalesce(var.events.archive_retention_days, local.prod ? 30 : 7)

  rules = {
    domain = {
      firehose_arn    = module.firehose.delivery_stream_arn
      description     = "Eventos de dominio al data lake"
      source_prefixes = var.events.source_prefixes
    }
  }

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_service" {
  security_group_id            = local.endpoints_sg
  referenced_security_group_id = module.service.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS desde las tareas de la aplicacion"

  tags = var.tags
}

module "alarms" {
  source = "../../../modules/observability/alarms"

  project            = var.project
  environment        = var.environment
  kms_key_arn        = local.platform_key
  existing_topic_arn = local.alarm_topic

  alb             = local.monitored_alb
  ecs_services    = { for k, v in local.monitored_ecs : k => merge(v, { min_running_tasks = coalesce(var.service.min_tasks, local.prod ? 2 : 1) }) }
  aurora_clusters = local.monitored_aurora
  elasticache     = local.monitored_cache

  tags = var.tags
}

module "dashboard" {
  source = "../../../modules/observability/dashboard"

  project     = var.project
  environment = var.environment
  name        = "${local.name}-ecommerce-t1"
  alarm_arns  = module.alarms.alarm_arns

  alb             = local.monitored_alb
  ecs_services    = local.monitored_ecs
  aurora_clusters = { for k, v in local.monitored_aurora : k => { cluster_id = v.cluster_id } }
  elasticache     = local.monitored_cache

  # Widgets de Application Signals (los SLO son un paso manual del runbook: el provider no tiene recurso).
  application_signals = local.otel_enabled ? { service_name = "${local.name}-app", environment_name = var.environment } : null
}

resource "aws_ssm_parameter" "layer" {
  for_each = local.ssm_parameters

  name  = "/${var.project}/${var.environment}/app/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
