locals {
  prod   = var.environment == "prod"
  region = data.aws_region.current.region
  tier   = "growth"

  network_prefix = "/${var.project}/${var.environment}/network/"
  network = {
    for i, n in data.aws_ssm_parameters_by_path.network.names :
    trimprefix(n, local.network_prefix) => nonsensitive(data.aws_ssm_parameters_by_path.network.values[i])
  }

  vpc_id          = local.network["vpc_id"]
  app_subnet_ids  = split(",", local.network["subnet_ids/app"])
  data_subnet_ids = split(",", local.network["subnet_ids/data"])

  log_retention_days = local.prod ? 365 : 30

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

  ssm_parameters = {
    "kms_key_arn"                = module.kms.key_arn
    "postgres/security_group_id" = module.postgres.security_group_id
    "postgres/instance_id"       = module.postgres.instance_id
  }
}
