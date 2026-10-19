locals {
  name       = "${var.project}-${var.environment}"
  prod       = var.environment == "prod"
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
  tier       = "enterprise"

  log_retention_days = local.prod ? 365 : 30
  pool_prefix        = var.pool_strategy == "per_tier" ? "tier" : "tenant"

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

  onboarding_environment = merge(
    {
      REGISTRY_TABLE = module.registry.table_name
      POOL_STRATEGY  = var.pool_strategy
      USER_POOLS     = jsonencode({ for k, p in module.pools : k => p.user_pool_id })
      EVENT_BUS_NAME = module.events.bus_name
    },
    var.silo_pipeline == null ? null : {
      GITHUB_APP_SECRET_ARN = aws_secretsmanager_secret.github_app[0].arn
      GITHUB_REPOSITORY     = var.silo_pipeline.repository
      GITHUB_WORKFLOW       = var.silo_pipeline.workflow
    },
  )

  onboarding_policies = merge(
    {
      registry = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "TenantRegistry"
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query"]
          Resource = module.registry.iam_resource_arns
        }]
      })
      identity = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          # Alta de usuarios con custom:tenant_id (no escribible por los app clients) y grupo de administradores.
          Sid    = "TenantUsers"
          Effect = "Allow"
          Action = [
            "cognito-idp:AdminCreateUser",
            "cognito-idp:AdminGetUser",
            "cognito-idp:AdminAddUserToGroup",
            "cognito-idp:AdminUpdateUserAttributes",
            "cognito-idp:AdminDisableUser",
          ]
          Resource = [for p in module.pools : p.user_pool_arn]
        }]
      })
      events = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "TenantLifecycleEvents"
          Effect   = "Allow"
          Action   = ["events:PutEvents"]
          Resource = [module.events.bus_arn]
        }]
      })
    },
    var.silo_pipeline == null ? null : {
      github-app = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "GitHubAppKey"
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = [aws_secretsmanager_secret.github_app[0].arn]
        }]
      })
    },
  )

  ssm_parameters = {
    "issuers"             = join(",", [for p in module.pools : p.issuer_url])
    "event_bus_arn"       = module.events.bus_arn
    "registry_table_name" = module.registry.table_name
  }
}
