locals {
  name       = "${var.project}-${var.environment}"
  prod       = var.environment == "prod"
  aurora     = var.database == "aurora_data_api"
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id

  # Nivel de backup (etiqueta BackupPlan que leen los módulos de datos y resilience/backup-plan).
  tier = "starter"

  log_retention_days = local.prod ? 365 : 30

  callback_urls = length(var.auth.callback_urls) > 0 ? var.auth.callback_urls : ["https://${var.domain_name}/auth/callback"]
  logout_urls   = length(var.auth.logout_urls) > 0 ? var.auth.logout_urls : ["https://${var.domain_name}/"]

  viewer_certificate_arn = var.viewer_certificate_arn != null ? var.viewer_certificate_arn : module.viewer_certificate[0].certificate_arn

  aurora_min_capacity = coalesce(var.aurora.min_capacity, local.prod ? 0.5 : 0)

  # Fuera de prod: retenciones cortas y sin regla continua ni almacenamiento frío (coste mínimo).
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

  # Variables de entorno que el blueprint inyecta en la Lambda (no secretas: solo nombres y ARNs).
  api_environment = merge(
    {
      ORIGIN_VERIFY_HEADER     = "x-origin-verify"
      ORIGIN_VERIFY_SECRET_ARN = aws_secretsmanager_secret.origin_verify.arn
      EVENT_BUS_NAME           = module.events.bus_name
    },
    local.aurora ? {
      DB_CLUSTER_ARN = module.aurora[0].cluster_arn
      DB_SECRET_ARN  = module.aurora[0].app_secret_arn
      DB_NAME        = module.aurora[0].database_name
    } : null,
    local.aurora ? null : { TABLE_NAME = module.table[0].table_name },
  )

  api_policies = merge(
    {
      origin-verify = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "ReadOriginVerifyToken"
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
          Resource = [aws_secretsmanager_secret.origin_verify.arn]
        }]
      })
      events = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "PublishDomainEvents"
          Effect   = "Allow"
          Action   = ["events:PutEvents"]
          Resource = [module.events.bus_arn]
        }]
      })
    },
    local.aurora ? {
      data-api = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "DataApi"
            Effect = "Allow"
            Action = [
              "rds-data:ExecuteStatement",
              "rds-data:BatchExecuteStatement",
              "rds-data:BeginTransaction",
              "rds-data:CommitTransaction",
              "rds-data:RollbackTransaction",
            ]
            Resource = [module.aurora[0].cluster_arn]
          },
          {
            # Usuario app_runtime (nunca el maestro): su secreto lo rota la función multiusuario.
            Sid      = "ReadAppRuntimeSecret"
            Effect   = "Allow"
            Action   = ["secretsmanager:GetSecretValue"]
            Resource = [module.aurora[0].app_secret_arn]
          },
        ]
      })
    } : null,
    local.aurora ? null : {
      dynamodb = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "ShopTable"
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:BatchGetItem",
            "dynamodb:Query",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:ConditionCheckItem",
          ]
          Resource = module.table[0].iam_resource_arns
        }]
      })
    },
  )

  # Recursos vigilados: una sola declaración para alarmas y dashboard (misma forma de entrada).
  monitored_lambdas = { api = { function_name = module.api_function.function_name, timeout_seconds = var.api_function.timeout_seconds } }
  monitored_tables  = { for k, v in { shop = { table_name = try(module.table[0].table_name, "") } } : k => v if !local.aurora }
  monitored_aurora  = { for k, v in { main = { cluster_id = try(module.aurora[0].cluster_id, ""), has_replicas = local.prod } } : k => v if local.aurora }
  monitored_waf     = { for k, v in { edge = { web_acl_name = coalesce(module.waf.web_acl_name, "none") } } : k => v if var.waf_mode == "web_acl" }
  monitored_cdn     = { site = { distribution_id = module.site.distribution_id } }
}
