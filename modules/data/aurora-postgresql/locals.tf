locals {
  name = coalesce(var.name, "${var.project}-${var.environment}-aurora")

  engine_major = split(".", var.engine_version)[0]

  serverless = var.capacity_mode == "serverless_v2"

  instance_class      = local.serverless ? "db.serverless" : var.instance_class
  instance_count      = coalesce(var.instance_count, var.environment == "prod" ? 2 : 1)
  deletion_protection = coalesce(var.deletion_protection, var.environment != "dev")

  backup_retention_days = coalesce(var.backup.retention_days, var.environment == "prod" ? 35 : 7)

  # Database Insights advanced exige la retención más larga de Performance Insights (465 días).
  insights_retention_days = var.database_insights_mode == "advanced" ? 465 : 7

  # Claves estables "1".."n": quitar lectores por el final no recrea el resto.
  instances = { for i in range(local.instance_count) : tostring(i + 1) => i }

  # Reparto en round-robin; el índice 0 (writer inicial) cae en la primera AZ.
  instance_azs = {
    for k, i in local.instances : k => var.az_names == null ? null : var.az_names[i % length(var.az_names)]
  }

  postgres_log_group = "/aws/rds/cluster/${local.name}/postgresql"

  ssm_prefix = "/${var.project}/${var.environment}/data/${var.ssm_namespace}"
}
