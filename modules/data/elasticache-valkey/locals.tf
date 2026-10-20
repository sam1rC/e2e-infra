locals {
  name = coalesce(var.name, "${var.project}-${var.environment}-valkey")

  engine_major = split(".", var.engine_version)[0]

  num_cache_clusters = coalesce(var.num_cache_clusters, var.environment == "prod" ? 2 : 1)
  has_replicas       = local.num_cache_clusters >= 2

  # Los IDs de usuario de ElastiCache son únicos por cuenta y región, de ahí el prefijo <name>.
  user_ids = { for k, _ in var.iam_users : k => "${local.name}-${k}" }

  # Registros de ElastiCache a CloudWatch Logs: slow-log y engine-log.
  log_types = {
    slow   = { type = "slow-log", group = "/aws/elasticache/${local.name}/slow-log" }
    engine = { type = "engine-log", group = "/aws/elasticache/${local.name}/engine-log" }
  }

  ssm_prefix = "/${var.project}/${var.environment}/data/${var.ssm_namespace}"
}
