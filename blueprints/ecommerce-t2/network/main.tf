# CMK de plataforma del entorno: logs de todas las capas, topic de alarmas, ECR y bus de eventos.
# Los datos (bases de datos, secretos de BD) tienen su propia clave en la capa data.
module "kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "platform"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = [
    "logs.${local.region}.amazonaws.com",
    "cloudwatch.amazonaws.com",
    "sns.amazonaws.com",
    "events.amazonaws.com",
    "sqs.amazonaws.com",
  ]
  via_services = [
    "s3.${local.region}.amazonaws.com",
    "ecr.${local.region}.amazonaws.com",
    "sqs.${local.region}.amazonaws.com",
    "secretsmanager.${local.region}.amazonaws.com",
  ]

  tags = var.tags
}

# Bucket de logs de red y de acceso del ALB. SSE-S3: ni el ALB ni la entrega de logs admiten SSE-KMS aquí.
module "logs" {
  source = "../../../modules/storage/s3-bucket"

  project       = var.project
  environment   = var.environment
  purpose       = "logs"
  sse_algorithm = "AES256"
  force_destroy = !local.prod

  lifecycle_config = {
    transition_to_ia_days = local.prod ? 30 : null
    expiration_days       = local.prod ? 365 : 30
  }

  policy_statements = [
    {
      sid            = "AWSLogDeliveryWrite"
      actions        = ["s3:PutObject"]
      resource_paths = ["/AWSLogs/${local.account_id}/*"]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-acl", values = ["bucket-owner-full-control"] },
        { test = "StringEquals", variable = "aws:SourceAccount", values = [local.account_id] },
      ]
    },
    {
      sid            = "AWSLogDeliveryAclCheck"
      actions        = ["s3:GetBucketAcl", "s3:ListBucket"]
      resource_paths = [""]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions     = [{ test = "StringEquals", variable = "aws:SourceAccount", values = [local.account_id] }]
    },
    {
      sid            = "AllowAlbLogDelivery"
      actions        = ["s3:PutObject"]
      resource_paths = ["/alb/AWSLogs/${local.account_id}/*"]
      principals     = [{ type = "AWS", identifiers = [data.aws_elb_service_account.current.arn] }]
    },
  ]

  tags = var.tags
}

# Topic de alarmas del entorno: lo crean aquí (primera capa) para que data y app lo reutilicen
# (existing_topic_arn) y los destinatarios confirmen una sola suscripción.
module "notifications" {
  source = "../../../modules/observability/alarms"

  project             = var.project
  environment         = var.environment
  kms_key_arn         = module.kms.key_arn
  email_subscriptions = var.alarm_emails

  tags = var.tags
}

module "vpc" {
  source = "../../../modules/network/vpc"

  project     = var.project
  environment = var.environment
  cidr_block  = var.cidr_block
  az_names    = var.az_names

  # T2: una NAT zonal (coste mínimo con salida a Internet). Las subredes públicas solo alojan la NAT.
  nat_mode     = "zonal_single"
  subnet_tiers = { public = true, app = true, data = true }

  flow_logs     = { s3_bucket_arn = module.logs.bucket_arn }
  alarm_actions = [module.notifications.topic_arn]

  tags = var.tags
}

# Endpoints de VPC: las capas data y app añaden su regla de entrada 443 sobre security_group_id (ADR 0016).
module "endpoints" {
  source = "../../../modules/network/vpc-endpoints"

  project         = var.project
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block
  subnet_ids      = module.vpc.subnet_ids["app"]
  route_table_ids = concat(module.vpc.route_table_ids["app"], module.vpc.route_table_ids["data"])

  interface_services        = var.interface_endpoints
  ingress_from_other_layers = true

  tags = var.tags
}

resource "aws_ssm_parameter" "layer" {
  for_each = local.ssm_parameters

  name  = "/${var.project}/${var.environment}/network/${each.key}"
  type  = "String"
  value = each.value

  tags = var.tags
}
