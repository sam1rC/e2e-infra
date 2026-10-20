locals {
  prod       = var.environment == "prod"
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
  nat_mode   = coalesce(var.nat_mode, var.environment == "dev" ? "zonal_single" : "regional")

  # Salidas de la capa que leen data, app y edge (ADR 0004). Las de la VPC las publica el módulo vpc.
  ssm_parameters = {
    kms_key_arn                 = module.kms.key_arn
    logs_bucket_name            = module.logs.bucket_id
    logs_bucket_arn             = module.logs.bucket_arn
    endpoints_security_group_id = module.endpoints.security_group_id
    s3_prefix_list_id           = module.endpoints.gateway_endpoint_prefix_list_ids["s3"]
    alarm_topic_arn             = module.notifications.topic_arn
    az_names                    = join(",", var.az_names)
  }
}
