locals {
  name       = "${var.project}-${var.environment}"
  prod       = var.environment == "prod"
  account_id = data.aws_caller_identity.current.account_id

  network = {
    for i, n in data.aws_ssm_parameters_by_path.network.names :
    trimprefix(n, "/${var.project}/${var.environment}/network/") => nonsensitive(data.aws_ssm_parameters_by_path.network.values[i])
  }
  platform_key = local.network["kms_key_arn"]

  tenant_environment = merge(
    {
      JWT_ISSUERS        = join(",", var.jwt_issuers)
      TENANT_ID_CLAIM    = "custom:tenant_id"
      ISOLATION_MODEL    = var.isolation_model
      TENANT_ROLE_ARN    = module.tenant_role.role_arn
      TENANT_TAG_KEY     = module.tenant_role.tenant_tag_key
      TENANT_BUCKET      = module.tenant_bucket.bucket_id
      TENANT_DATA_PREFIX = "tenants/"
    },
    var.tenant_id == null ? null : { TENANT_ID = var.tenant_id },
    var.metering_bus_arn == null ? null : { METERING_BUS_ARN = var.metering_bus_arn, METERING_SOURCE = "saas.usage" },
  )

  tenant_policies = merge(
    {
      tenant-role = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "AssumeTenantRoleWithSessionTag"
          Effect   = "Allow"
          Action   = ["sts:AssumeRole", "sts:TagSession"]
          Resource = [module.tenant_role.role_arn]
        }]
      })
    },
    var.metering_bus_arn == null ? null : {
      metering = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "PublishUsageToControlPlane"
          Effect   = "Allow"
          Action   = ["events:PutEvents"]
          Resource = [var.metering_bus_arn]
        }]
      })
    },
  )
}
