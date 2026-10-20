locals {
  name      = "${var.project}-${var.environment}"
  prod      = var.environment == "prod"
  region    = data.aws_region.current.region
  dr_region = data.aws_region.dr.region
  tier      = "enterprise"

  network = {
    for i, n in data.aws_ssm_parameters_by_path.network.names :
    trimprefix(n, "/${var.project}/${var.environment}/network/") => nonsensitive(data.aws_ssm_parameters_by_path.network.values[i])
  }

  vpc_id          = local.network["vpc_id"]
  az_names        = split(",", local.network["az_names"])
  app_subnet_ids  = split(",", local.network["subnet_ids/app"])
  data_subnet_ids = split(",", local.network["subnet_ids/data"])
  endpoints_sg    = local.network["endpoints_security_group_id"]

  log_retention_days = local.prod ? 365 : 30

  aurora_instance_count = coalesce(var.aurora.instance_count, local.prod ? 2 : 1)
  cache_nodes           = coalesce(var.cache.num_cache_clusters, local.prod ? 2 : 1)
  dr_copy               = coalesce(var.dr_copy, local.prod)
  restore_testing       = coalesce(var.restore_testing, local.prod)

  backup_schedule = local.prod ? {
    daily_retention_days            = 35
    monthly_retention_days          = 365
    monthly_cold_storage_after_days = 30
    continuous_retention_days       = 35
    } : {
    daily_retention_days            = 7
    monthly_retention_days          = 30
    monthly_cold_storage_after_days = 0
    continuous_retention_days       = 0
  }

  # Obligatorio en prod para enterprise; irreversible tras changeable_for_days (riesgo documentado en el plan).
  vault_lock = local.prod ? { min_retention_days = 7, changeable_for_days = 3 } : null

  ssm_parameters = merge(
    {
      "kms_key_arn"              = module.kms.key_arn
      "aurora/security_group_id" = module.aurora.security_group_id
      "aurora/cluster_id"        = module.aurora.cluster_id
      "aurora/instance_count"    = tostring(local.aurora_instance_count)
    },
    var.cache.enabled ? {
      "valkey/security_group_id" = module.cache[0].security_group_id
      "valkey/iam_user_name"     = module.cache[0].iam_user_names["app"]
      "valkey/iam_user_arn"      = module.cache[0].iam_connect_resource_arns["app"][1]
      "valkey/node_count"        = tostring(local.cache_nodes)
    } : null,
  )
}
