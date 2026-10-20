locals {
  name = "${var.project}-${var.environment}"

  anomaly_monitor_arn = var.existing_anomaly_monitor_arn != null ? var.existing_anomaly_monitor_arn : aws_ce_anomaly_monitor.services[0].arn
}
