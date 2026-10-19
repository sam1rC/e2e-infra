# CMK de datos: almacenamiento de la base, secretos maestro y app_runtime, Database Insights y logs.
module "kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "data"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = ["logs.${local.region}.amazonaws.com"]
  via_services = [
    "rds.${local.region}.amazonaws.com",
    "secretsmanager.${local.region}.amazonaws.com",
  ]

  tags = var.tags
}

module "postgres" {
  source = "../../../modules/data/rds-postgresql"

  project        = var.project
  environment    = var.environment
  vpc_id         = local.vpc_id
  subnet_ids     = local.data_subnet_ids
  kms_key_arn    = module.kms.key_arn
  engine_version = var.engine_version
  instance_class = coalesce(var.instance_class, local.prod ? "db.m7g.large" : "db.t4g.micro")
  multi_az       = var.multi_az
  storage        = var.storage

  backup_plan         = local.tier
  skip_final_snapshot = !local.prod
  apply_immediately   = !local.prod
  monitoring_interval = local.prod ? 60 : 0
  log_retention_days  = local.log_retention_days

  # Rotación multiusuario de app_runtime: la función vive en las subredes app y sale por el endpoint
  # de Secrets Manager de la capa network (regla de entrada abajo).
  app_secret_rotation = {
    subnet_ids                 = local.app_subnet_ids
    endpoint_security_group_id = local.network["endpoints_security_group_id"]
  }
  app_secret_recovery_window_in_days = local.prod ? null : 0

  # La capa app añade la entrada desde las tareas (ADR 0016).
  allowed_security_group_ids = {}

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_rotation" {
  security_group_id            = local.network["endpoints_security_group_id"]
  referenced_security_group_id = module.postgres.rotation_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS desde la funcion de rotacion de app_runtime"

  tags = var.tags
}

module "backup_kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "backup"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.${local.region}.amazonaws.com"]

  tags = var.tags
}

module "backup" {
  source = "../../../modules/resilience/backup-plan"

  project     = var.project
  environment = var.environment
  kms_key_arn = module.backup_kms.key_arn
  tier        = local.tier
  schedule    = local.backup_schedule

  # Obligatorio en prod para growth; irreversible tras changeable_for_days (riesgo documentado en el plan).
  vault_lock = local.prod ? { min_retention_days = 7, changeable_for_days = 3 } : null

  alarm_actions = [local.network["alarm_topic_arn"]]

  tags = var.tags
}

resource "aws_ssm_parameter" "layer" {
  for_each = local.ssm_parameters

  name  = "/${var.project}/${var.environment}/data/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
