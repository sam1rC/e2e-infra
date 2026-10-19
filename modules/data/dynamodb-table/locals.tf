locals {
  table_name = "${var.project}-${var.environment}-${var.name}"

  provisioned = var.billing_mode == "PROVISIONED"

  deletion_protection = coalesce(var.deletion_protection, var.environment != "dev")
  pitr_days           = coalesce(var.point_in_time_recovery_days, var.environment == "prod" ? 35 : 7)

  ssm_prefix = "/${var.project}/${var.environment}/data/dynamodb/${var.name}"
}
