locals {
  name = "${var.project}-${var.environment}"
  prod = var.environment == "prod"

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
  db_sg          = local.data["postgres/security_group_id"]

  log_retention_days = local.prod ? 365 : 30

  alb_certificate_arn = var.alb_certificate_arn != null ? var.alb_certificate_arn : module.alb_certificate[0].certificate_arn

  # Salida de las tareas: endpoints de VPC (ECR, logs, secretos), S3 (capas de ECR), la base de datos y,
  # opcionalmente, HTTPS a Internet por la NAT.
  egress_rules = merge(
    {
      endpoints = { description = "Endpoints de VPC", port = 443, security_group_id = local.endpoints_sg }
      s3        = { description = "S3 por el endpoint gateway (capas de ECR)", port = 443, prefix_list_id = local.network["s3_prefix_list_id"] }
      postgres  = { description = "PostgreSQL", port = tonumber(local.data["postgres/port"]), security_group_id = local.db_sg }
    },
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
  monitored_rds = {
    main = { instance_id = local.data["postgres/instance_id"] }
  }

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
