resource "aws_db_subnet_group" "this" {
  name        = local.name
  description = "Subredes de datos de ${local.name}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_rds_cluster_parameter_group" "this" {
  name_prefix = "${local.name}-"
  description = "Parametros de seguridad de ${local.name}"
  family      = "aurora-postgresql${local.engine_major}"

  # TLS obligatorio y trazabilidad de conexiones y DDL.
  # Estático: AWS lo guarda como pending-reboot (con immediate el plan nunca converge; sandbox, 2026-10-14).
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = tostring(var.log_min_duration_statement)
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pgaudit"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "pgaudit.log"
    value = "ddl,role"
  }

  tags = merge(var.tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS crea este log group sin retención ni cifrado si no existe: se crea antes con la CMK.
resource "aws_cloudwatch_log_group" "postgresql" {
  name              = local.postgres_log_group
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = local.name
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name
  port               = var.port

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # La contraseña maestra la genera y rota RDS en Secrets Manager: no existe en código ni en el estado.
  master_username                     = var.master_username
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.kms_key_arn
  iam_database_authentication_enabled = true
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.this.id]
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.this.name
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  enable_http_endpoint                = var.enable_http_endpoint
  database_insights_mode              = var.database_insights_mode
  allow_major_version_upgrade         = false
  auto_minor_version_upgrade          = var.auto_minor_version_upgrade
  apply_immediately                   = var.apply_immediately
  backup_retention_period             = local.backup_retention_days
  preferred_backup_window             = var.backup.window
  preferred_maintenance_window        = var.backup.maintenance_window
  copy_tags_to_snapshot               = true
  deletion_protection                 = local.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${local.name}-final")

  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.serverless ? [var.serverless_v2] : []

    content {
      min_capacity             = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity             = serverlessv2_scaling_configuration.value.max_capacity
      seconds_until_auto_pause = serverlessv2_scaling_configuration.value.seconds_until_auto_pause
    }
  }

  tags = merge(var.tags, { Name = local.name }, var.backup_plan == null ? null : { BackupPlan = var.backup_plan })

  depends_on = [aws_cloudwatch_log_group.postgresql]
}

resource "aws_rds_cluster_instance" "this" {
  for_each = local.instances

  identifier         = "${local.name}-${each.key}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  instance_class     = local.instance_class
  availability_zone  = local.instance_azs[each.key]
  promotion_tier     = each.value == 0 ? 0 : var.promotion_tier

  db_subnet_group_name       = aws_db_subnet_group.this.name
  publicly_accessible        = false
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  copy_tags_to_snapshot      = true

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = local.insights_retention_days

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  tags = merge(var.tags, { Name = "${local.name}-${each.key}" })
}
