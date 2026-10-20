locals {
  name = "${var.project}-${var.environment}"
  prod = var.environment == "prod"

  account_id = data.aws_caller_identity.current.account_id

  # Salidas de las capas network y data (ADR 0004).
  network = {
    for i, n in data.aws_ssm_parameters_by_path.network.names :
    trimprefix(n, "/${var.project}/${var.environment}/network/") => nonsensitive(data.aws_ssm_parameters_by_path.network.values[i])
  }
  data = {
    for i, n in data.aws_ssm_parameters_by_path.data.names :
    trimprefix(n, "/${var.project}/${var.environment}/data/") => nonsensitive(data.aws_ssm_parameters_by_path.data.values[i])
  }

  vpc_id         = local.network["vpc_id"]
  app_subnet_ids = split(",", local.network["subnet_ids/app"])
  platform_key   = local.network["kms_key_arn"]
  alarm_topic    = local.network["alarm_topic_arn"]
  endpoints_sg   = local.network["endpoints_security_group_id"]
  db_sg          = local.data["aurora/security_group_id"]
  db_port        = tonumber(local.data["aurora/port"])
  cache_enabled  = contains(keys(local.data), "valkey/security_group_id")
  otel_enabled   = var.service.otel_image != null

  log_retention_days = local.prod ? 365 : 30

  alb_certificate_arn = var.alb_certificate_arn != null ? var.alb_certificate_arn : module.alb_certificate[0].certificate_arn

  # Salida de las tareas: endpoints de VPC (ECR, logs, secretos), S3 (capas de ECR), la base de datos y,
  # opcionalmente, HTTPS a Internet por la NAT.
  egress_rules = merge(
    {
      endpoints = { description = "Endpoints de VPC", port = 443, security_group_id = local.endpoints_sg }
      s3        = { description = "S3 por el endpoint gateway (capas de ECR)", port = 443, prefix_list_id = local.network["s3_prefix_list_id"] }
      postgres  = { description = "Aurora PostgreSQL", port = local.db_port, security_group_id = local.db_sg }
    },
    local.cache_enabled ? {
      valkey = { description = "Valkey (TLS)", port = tonumber(local.data["valkey/port"]), security_group_id = local.data["valkey/security_group_id"] }
    } : null,
    var.allow_internet_egress ? {
      internet = { description = "HTTPS saliente por la NAT", port = 443, cidr_ipv4 = "0.0.0.0/0" }
    } : null,
  )

  monitored_alb = {
    app = {
      alb_arn_suffix          = module.alb.alb_arn_suffix
      target_group_arn_suffix = module.alb.target_group_arn_suffixes["app"]
    }
  }
  monitored_ecs = {
    app = { cluster_name = module.cluster.cluster_name, service_name = module.service.service_name }
  }
  monitored_aurora = {
    main = { cluster_id = local.data["aurora/cluster_id"], has_replicas = tonumber(local.data["aurora/instance_count"]) > 1 }
  }
  monitored_cache = {
    for k, v in { main = { replication_group_id = try(local.data["valkey/replication_group_id"], ""), node_count = tonumber(try(local.data["valkey/node_count"], "1")) } } :
    k => v if local.cache_enabled
  }

  app_environment = merge(
    {
      DB_HOST        = local.data["aurora/writer_endpoint"]
      DB_READER_HOST = local.data["aurora/reader_endpoint"]
      DB_PORT        = local.data["aurora/port"]
      DB_NAME        = local.data["aurora/database_name"]
      EVENT_BUS_NAME = module.events.bus_name
    },
    local.cache_enabled ? {
      CACHE_HOST                 = local.data["valkey/primary_endpoint"]
      CACHE_READER_HOST          = local.data["valkey/reader_endpoint"]
      CACHE_PORT                 = local.data["valkey/port"]
      CACHE_USER                 = local.data["valkey/iam_user_name"]
      CACHE_REPLICATION_GROUP_ID = local.data["valkey/replication_group_id"]
    } : null,
    local.otel_enabled ? {
      OTEL_SERVICE_NAME           = "${local.name}-app"
      OTEL_RESOURCE_ATTRIBUTES    = "deployment.environment=${var.environment}"
      OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"
    } : null,
  )

  task_role_policies = merge(
    {
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
    local.cache_enabled ? {
      valkey = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          # Autenticación IAM de Valkey: hacen falta el replication group y el usuario.
          Sid      = "ValkeyIamAuth"
          Effect   = "Allow"
          Action   = ["elasticache:Connect"]
          Resource = [local.data["valkey/replication_group_arn"], local.data["valkey/iam_user_arn"]]
        }]
      })
    } : null,
    var.extra_task_role_policies,
  )

  ssm_parameters = {
    alb_arn                   = module.alb.alb_arn
    alb_dns_name              = module.alb.alb_dns_name
    alb_security_group_id     = module.alb.security_group_id
    service_security_group_id = module.service.security_group_id
    task_role_arn             = module.service.task_role_arn
    ecr_repository_url        = module.ecr.repository_url
    cluster_name              = module.cluster.cluster_name
    service_name              = module.service.service_name
  }
}
