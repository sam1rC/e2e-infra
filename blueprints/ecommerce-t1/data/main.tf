# CMK de datos: almacenamiento de Aurora y Valkey, secretos maestro y app_runtime, Database Insights y logs.
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
    "elasticache.${local.region}.amazonaws.com",
  ]

  tags = var.tags
}

module "aurora" {
  source = "../../../modules/data/aurora-postgresql"

  project        = var.project
  environment    = var.environment
  vpc_id         = local.vpc_id
  subnet_ids     = local.data_subnet_ids
  az_names       = local.az_names
  kms_key_arn    = module.kms.key_arn
  engine_version = var.aurora.engine_version

  capacity_mode          = "provisioned"
  instance_class         = coalesce(var.aurora.instance_class, local.prod ? "db.r7g.large" : "db.t4g.medium")
  instance_count         = local.aurora_instance_count
  database_insights_mode = coalesce(var.aurora.database_insights_mode, local.prod ? "advanced" : "standard")

  backup_plan         = local.tier
  skip_final_snapshot = !local.prod
  apply_immediately   = !local.prod
  monitoring_interval = local.prod ? 60 : 0
  log_retention_days  = local.log_retention_days

  app_secret_rotation = {
    subnet_ids                 = local.app_subnet_ids
    endpoint_security_group_id = local.endpoints_sg
  }
  app_secret_recovery_window_in_days = local.prod ? null : 0

  # La capa app añade la entrada desde las tareas (ADR 0016).
  allowed_security_group_ids = {}

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_rotation" {
  security_group_id            = local.endpoints_sg
  referenced_security_group_id = module.aurora.rotation_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS desde la funcion de rotacion de app_runtime"

  tags = var.tags
}

# Valkey con autenticación IAM: la aplicación firma un token con su task role; no hay contraseñas.
module "cache" {
  source = "../../../modules/data/elasticache-valkey"
  count  = var.cache.enabled ? 1 : 0

  project            = var.project
  environment        = var.environment
  vpc_id             = local.vpc_id
  subnet_ids         = local.data_subnet_ids
  kms_key_arn        = module.kms.key_arn
  engine_version     = var.cache.engine_version
  node_type          = coalesce(var.cache.node_type, local.prod ? "cache.m7g.large" : "cache.t4g.micro")
  num_cache_clusters = local.cache_nodes

  final_snapshot_enabled = local.prod
  apply_immediately      = !local.prod
  log_retention_days     = local.log_retention_days

  allowed_security_group_ids = {}

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

# Vault de DR en otra región: destino de las copias (RPO 24 h ante la pérdida de la región).
module "dr_backup_kms" {
  source    = "../../../modules/foundation/kms-key"
  providers = { aws = aws.dr }
  count     = local.dr_copy ? 1 : 0

  project                 = var.project
  environment             = var.environment
  purpose                 = "backup-dr"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.${local.dr_region}.amazonaws.com"]

  tags = var.tags
}

module "dr_backup" {
  source    = "../../../modules/resilience/backup-plan"
  providers = { aws = aws.dr }
  count     = local.dr_copy ? 1 : 0

  project      = var.project
  environment  = var.environment
  name         = "dr"
  kms_key_arn  = module.dr_backup_kms[0].key_arn
  plan_enabled = false
  vault_lock   = local.vault_lock

  publish_ssm_parameters = false

  tags = var.tags
}

module "backup" {
  source = "../../../modules/resilience/backup-plan"

  project     = var.project
  environment = var.environment
  kms_key_arn = module.backup_kms.key_arn
  tier        = local.tier
  schedule    = local.backup_schedule
  vault_lock  = local.vault_lock

  copy_destinations = local.dr_copy ? { dr = { vault_arn = module.dr_backup[0].vault_arn } } : {}

  # Restauración mensual del último recovery point de Aurora en la VPC del entorno (no en la VPC por defecto).
  restore_testing = local.restore_testing ? {
    resource_types = ["Aurora"]
    metadata_overrides = {
      Aurora = {
        dbsubnetgroupname   = "${local.name}-aurora"
        vpcsecuritygroupids = jsonencode([module.aurora.security_group_id])
      }
    }
  } : null

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
