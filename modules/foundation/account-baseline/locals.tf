locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  create_log_destination = var.log_archive == null
  log_bucket_name        = local.create_log_destination ? module.log_bucket[0].bucket_id : var.log_archive.bucket_name
  log_kms_key_arn        = local.create_log_destination ? module.kms.key_arn : var.log_archive.kms_key_arn

  # ARN del trail construido por nombre: la key policy y la bucket policy lo necesitan antes de que exista el trail.
  trail_name = "${local.name}-trail"
  trail_arn  = "arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"

  # CloudWatch Logs solo admite ciertos valores de retención: se elige el menor admitido >= log_retention_days.
  allowed_retention_days = [90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653]
  cloudwatch_retention   = [for d in local.allowed_retention_days : d if d >= var.log_retention_days][0]
}
