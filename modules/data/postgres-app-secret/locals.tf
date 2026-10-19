locals {
  rotation_enabled = var.rotation != null

  recovery_window_in_days = coalesce(var.recovery_window_in_days, var.environment == "prod" ? 30 : 7)

  rotation_function_name = "${var.name}-rotation"
}
