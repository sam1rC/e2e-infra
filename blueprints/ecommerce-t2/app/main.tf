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

  environment_variables = merge(var.service.environment_variables, {
    DB_HOST = local.data["postgres/endpoint"]
    DB_PORT = local.data["postgres/port"]
    DB_NAME = local.data["postgres/database_name"]
  })

  # Usuario app_runtime (nunca el maestro): JSON con username/password que rota Secrets Manager.
  secrets              = { DB_CREDENTIALS = local.data["postgres/app_secret_arn"] }
  secrets_kms_key_arns = [local.data["kms_key_arn"]]

  log_kms_key_arn    = local.platform_key
  log_retention_days = local.log_retention_days

  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arns["app"]
  alb_enabled           = true # el ALB se crea en este mismo apply
  egress_rules          = local.egress_rules
  task_role_policies    = var.extra_task_role_policies

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
  from_port                    = tonumber(local.data["postgres/port"])
  to_port                      = tonumber(local.data["postgres/port"])
  description                  = "PostgreSQL desde las tareas de la aplicacion"

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

  alb           = local.monitored_alb
  ecs_services  = { for k, v in local.monitored_ecs : k => merge(v, { min_running_tasks = coalesce(var.service.min_tasks, local.prod ? 2 : 1) }) }
  rds_instances = local.monitored_rds

  tags = var.tags
}

module "dashboard" {
  source = "../../../modules/observability/dashboard"

  project     = var.project
  environment = var.environment
  name        = "${local.name}-ecommerce-t2"
  alarm_arns  = module.alarms.alarm_arns

  alb           = local.monitored_alb
  ecs_services  = local.monitored_ecs
  rds_instances = local.monitored_rds
}

resource "aws_ssm_parameter" "layer" {
  for_each = local.ssm_parameters

  name  = "/${var.project}/${var.environment}/app/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
