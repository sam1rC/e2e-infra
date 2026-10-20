locals {
  # Conocido al planificar aunque el ARN del bucket se calcule en el mismo apply.
  access_logs = var.access_logs_enabled != null ? var.access_logs_enabled : var.log_bucket_arn != null

  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  s3_origin_id  = "s3"
  api_origin_id = "api"

  create_kms  = var.kms_key_arn == null
  kms_key_arn = local.create_kms ? module.kms[0].key_arn : var.kms_key_arn

  dns_records = var.zone_id == null ? {} : {
    for pair in setproduct(var.domain_names, ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => { name = pair[0], type = pair[1] }
  }

  # Solo la distribución puede leer los objetos (OAC); se referencia por ARN exacto.
  cloudfront_read_statement = {
    sid            = "AllowCloudFrontServicePrincipalRead"
    actions        = ["s3:GetObject"]
    resource_paths = ["/*"]
    principals     = [{ type = "Service", identifiers = ["cloudfront.amazonaws.com"] }]
    conditions     = [{ test = "StringEquals", variable = "AWS:SourceArn", values = [aws_cloudfront_distribution.this.arn] }]
  }
}
