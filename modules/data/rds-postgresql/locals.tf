locals {
  name = coalesce(var.name, "${var.project}-${var.environment}-postgres")

  engine_major = split(".", var.engine_version)[0]

  multi_az            = coalesce(var.multi_az, var.environment == "prod")
  deletion_protection = coalesce(var.deletion_protection, var.environment != "dev")

  backup_retention_days = coalesce(var.backup.retention_days, var.environment == "prod" ? 35 : 7)

  # Database Insights advanced exige la retención más larga de Performance Insights (465 días).
  insights_retention_days = var.database_insights_mode == "advanced" ? 465 : 7

  postgres_log_group = "/aws/rds/instance/${local.name}/postgresql"

  ssm_prefix = "/${var.project}/${var.environment}/data/${var.ssm_namespace}"
}
