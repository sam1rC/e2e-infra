resource "aws_backup_restore_testing_plan" "this" {
  count = var.restore_testing == null ? 0 : 1

  name                = "${local.restore_name}_restore"
  schedule_expression = var.restore_testing.schedule_expression
  start_window_hours  = var.restore_testing.start_window_hours

  recovery_point_selection {
    algorithm             = "LATEST_WITHIN_WINDOW"
    include_vaults        = [aws_backup_vault.this.arn]
    recovery_point_types  = ["CONTINUOUS", "SNAPSHOT"]
    selection_window_days = var.restore_testing.recovery_window_days
  }

  tags = merge(var.tags, { Name = "${local.vault_name}-restore-testing" })
}

# Una selección por tipo de recurso, limitada a los recursos del tier (etiqueta BackupPlan).
resource "aws_backup_restore_testing_selection" "this" {
  for_each = local.restore_resource_types

  name                       = "${local.restore_name}_${lower(each.key)}"
  restore_testing_plan_name  = aws_backup_restore_testing_plan.this[0].name
  protected_resource_type    = each.key
  iam_role_arn               = aws_iam_role.backup[0].arn
  validation_window_hours    = var.restore_testing.validation_window_hours
  restore_metadata_overrides = lookup(var.restore_testing.metadata_overrides, each.key, {})

  protected_resource_conditions {
    string_equals {
      key   = "aws:ResourceTag/BackupPlan"
      value = var.tier
    }
  }
}
