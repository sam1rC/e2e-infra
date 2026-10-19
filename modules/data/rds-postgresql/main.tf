resource "aws_db_subnet_group" "this" {
  name        = local.name
  description = "Subredes de datos de ${local.name}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.name}-"
  description = "Parametros de seguridad de ${local.name}"
  family      = "postgres${local.engine_major}"

  # TLS obligatorio y trazabilidad de conexiones y DDL.
  # Estático en RDS PostgreSQL: AWS lo guarda como pending-reboot (con immediate el plan nunca converge).
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

resource "aws_db_instance" "this" {
  identifier        = local.name
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  db_name           = var.database_name
  port              = var.port
  availability_zone = local.multi_az ? null : var.availability_zone
  multi_az          = local.multi_az

  storage_type          = "gp3"
  allocated_storage     = var.storage.allocated_gb
  max_allocated_storage = var.storage.max_allocated_gb == 0 ? null : var.storage.max_allocated_gb
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # La contraseña maestra la genera y rota RDS en Secrets Manager: no existe en código ni en el estado.
  username                            = var.master_username
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.kms_key_arn
  iam_database_authentication_enabled = true

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  parameter_group_name            = aws_db_parameter_group.this.name
  publicly_accessible             = false
  enabled_cloudwatch_logs_exports = ["postgresql"]

  database_insights_mode                = var.database_insights_mode
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = local.insights_retention_days
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade
  apply_immediately           = var.apply_immediately

  backup_retention_period   = local.backup_retention_days
  backup_window             = var.backup.window
  maintenance_window        = var.backup.maintenance_window
  copy_tags_to_snapshot     = true
  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${local.name}-final")

  tags = merge(var.tags, { Name = local.name }, var.backup_plan == null ? null : { BackupPlan = var.backup_plan })

  depends_on = [aws_cloudwatch_log_group.postgresql]
}
