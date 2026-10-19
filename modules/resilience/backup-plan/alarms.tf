# Métricas agregadas de la cuenta y región de AWS Backup. Sin trabajos fallidos no hay datos: notBreaching.
resource "aws_cloudwatch_metric_alarm" "backup_jobs_failed" {
  count = var.plan_enabled ? 1 : 0

  alarm_name          = "${local.vault_name}-backup-jobs-failed"
  alarm_description   = "Trabajos de backup fallidos en ${local.vault_name}"
  namespace           = "AWS/Backup"
  metric_name         = "NumberOfBackupJobsFailed"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 3600
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  tags = merge(var.tags, { Name = "${local.vault_name}-backup-jobs-failed" })
}

resource "aws_cloudwatch_metric_alarm" "copy_jobs_failed" {
  count = length(var.copy_destinations) > 0 ? 1 : 0

  alarm_name          = "${local.vault_name}-copy-jobs-failed"
  alarm_description   = "Trabajos de copia entre vaults fallidos en ${local.vault_name}"
  namespace           = "AWS/Backup"
  metric_name         = "NumberOfCopyJobsFailed"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 3600
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  tags = merge(var.tags, { Name = "${local.vault_name}-copy-jobs-failed" })
}

resource "aws_cloudwatch_metric_alarm" "restore_jobs_failed" {
  count = var.restore_testing == null ? 0 : 1

  alarm_name          = "${local.vault_name}-restore-jobs-failed"
  alarm_description   = "Pruebas de restauración fallidas en ${local.vault_name}"
  namespace           = "AWS/Backup"
  metric_name         = "NumberOfRestoreJobsFailed"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  period              = 3600
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  tags = merge(var.tags, { Name = "${local.vault_name}-restore-jobs-failed" })
}
