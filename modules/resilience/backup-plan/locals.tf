locals {
  vault_name = "${var.project}-${var.environment}-${var.name}"

  # Los nombres del plan de pruebas de restauración solo admiten letras, dígitos y guiones bajos.
  restore_name = replace("${var.project}-${var.environment}-${var.name}", "-", "_")

  continuous_enabled = var.plan_enabled && var.schedule.continuous_retention_days > 0
  cold_storage_days  = var.schedule.monthly_cold_storage_after_days > 0 ? var.schedule.monthly_cold_storage_after_days : null

  restore_resource_types = var.restore_testing == null ? toset([]) : toset(var.restore_testing.resource_types)

  ssm_prefix = "/${var.project}/${var.environment}/resilience"
}
