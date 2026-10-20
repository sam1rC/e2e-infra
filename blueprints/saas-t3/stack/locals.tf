locals {
  name       = "${var.project}-${var.environment}"
  prod       = var.environment == "prod"
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id

  tier               = "starter"
  log_retention_days = local.prod ? 365 : 30

  callback_urls = length(var.auth.callback_urls) > 0 ? var.auth.callback_urls : ["https://${var.domain_name}/auth/callback"]
  logout_urls   = length(var.auth.logout_urls) > 0 ? var.auth.logout_urls : ["https://${var.domain_name}/"]

  viewer_certificate_arn = var.viewer_certificate_arn != null ? var.viewer_certificate_arn : module.viewer_certificate[0].certificate_arn

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

  # La Lambda no tiene acceso directo a la tabla: asume el rol del tenant (ABAC, dynamodb:LeadingKeys) con
  # la etiqueta de sesión del tenant validado en el JWT y cachea esas credenciales por tenant (A10).
  api_environment = {
    TABLE_NAME               = module.table.table_name
    TENANT_ROLE_ARN          = module.tenant_role.role_arn
    TENANT_TAG_KEY           = module.tenant_role.tenant_tag_key
    TENANT_ID_CLAIM          = module.tenants.tenant_id_claim
    ORIGIN_VERIFY_HEADER     = "x-origin-verify"
    ORIGIN_VERIFY_SECRET_ARN = aws_secretsmanager_secret.origin_verify.arn
  }

  api_policies = {
    tenant-role = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "AssumeTenantRoleWithSessionTag"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole", "sts:TagSession"]
        Resource = [module.tenant_role.role_arn]
      }]
    })
    origin-verify = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "ReadOriginVerifyToken"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [aws_secretsmanager_secret.origin_verify.arn]
      }]
    })
  }

  monitored_lambdas = { api = { function_name = module.api_function.function_name, timeout_seconds = var.api_function.timeout_seconds } }
  monitored_rest    = { api = { api_name = "${local.name}-api", stage = module.api.stage_name } }
  monitored_tables  = { tenants = { table_name = module.table.table_name } }
  monitored_waf     = { for k, v in { edge = { web_acl_name = coalesce(module.waf.web_acl_name, "none") } } : k => v if var.waf_mode == "web_acl" }
  monitored_cdn     = { site = { distribution_id = module.site.distribution_id } }
}
