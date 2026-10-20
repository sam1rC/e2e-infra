locals {
  # Conocido al planificar aunque el ARN del bucket se calcule en el mismo apply.
  access_logs = var.access_logs_enabled != null ? var.access_logs_enabled : var.log_bucket_arn != null

  name      = "${var.project}-${var.environment}"
  origin_id = "alb"

  dns_records = var.zone_id == null ? {} : {
    for pair in setproduct(var.domain_names, ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => { name = pair[0], type = pair[1] }
  }
}
