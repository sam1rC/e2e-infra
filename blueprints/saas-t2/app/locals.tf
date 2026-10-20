locals {
  name       = "${var.project}-${var.environment}"
  prod       = var.environment == "prod"
  account_id = data.aws_caller_identity.current.account_id

  network = {
    for i, n in data.aws_ssm_parameters_by_path.network.names :
    trimprefix(n, "/${var.project}/${var.environment}/network/") => nonsensitive(data.aws_ssm_parameters_by_path.network.values[i])
  }
  platform_key = local.network["kms_key_arn"]

  callback_urls = length(var.auth.callback_urls) > 0 ? var.auth.callback_urls : ["https://${var.domain_name}/auth/callback"]
  logout_urls   = length(var.auth.logout_urls) > 0 ? var.auth.logout_urls : ["https://${var.domain_name}/"]

  # Configuración de tenants que recibe la aplicación (no secreta).
  tenant_environment = {
    USER_POOL_ID       = module.tenants.user_pool_id
    JWT_ISSUER         = module.tenants.issuer_url
    JWT_AUDIENCE       = module.tenants.client_ids["web"]
    TENANT_ID_CLAIM    = module.tenants.tenant_id_claim
    TENANT_ROLE_ARN    = module.tenant_role.role_arn
    TENANT_TAG_KEY     = module.tenant_role.tenant_tag_key
    TENANT_BUCKET      = module.tenant_bucket.bucket_id
    TENANT_DATA_PREFIX = "tenants/"
  }

  tenant_policies = {
    tenant-role = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "AssumeTenantRoleWithSessionTag"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole", "sts:TagSession"]
        Resource = [module.tenant_role.role_arn]
      }]
    })
  }
}
