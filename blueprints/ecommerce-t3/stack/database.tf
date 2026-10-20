# Opción A (por defecto): DynamoDB, sin VPC. La Lambda accede por IAM.
module "table" {
  source = "../../../modules/data/dynamodb-table"
  count  = local.aurora ? 0 : 1

  project     = var.project
  environment = var.environment
  name        = "shop"
  kms_key_arn = module.kms.key_arn

  # Diseño de tabla única: pk/sk para las entidades y un índice genérico para los accesos secundarios.
  attributes = { pk = "S", sk = "S", gsi1pk = "S", gsi1sk = "S" }
  hash_key   = "pk"
  range_key  = "sk"

  global_secondary_indexes = {
    gsi1 = { hash_key = "gsi1pk", range_key = "gsi1sk" }
  }

  ttl_attribute = "expires_at"

  tags = merge(var.tags, { BackupPlan = local.tier })
}

# Opción B: Aurora Serverless v2 + RDS Data API. La VPC solo aloja el cluster (sin NAT, sin IGW, solo
# subredes data); la Lambda queda fuera de la VPC y llama a la Data API por HTTPS con IAM + secreto.
module "vpc_logs" {
  source = "../../../modules/storage/s3-bucket"
  count  = local.aurora ? 1 : 0

  project       = var.project
  environment   = var.environment
  purpose       = "logs"
  bucket_name   = "${local.name}-vpc-logs-${local.account_id}"
  sse_algorithm = "AES256"
  force_destroy = !local.prod

  lifecycle_config = {
    expiration_days = local.prod ? 365 : 30
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
  ]

  tags = var.tags
}

module "vpc" {
  source = "../../../modules/network/vpc"
  count  = local.aurora ? 1 : 0

  project     = var.project
  environment = var.environment
  cidr_block  = var.aurora.vpc_cidr
  az_names    = var.aurora.az_names

  subnet_tiers            = { public = false, app = false, data = true }
  nat_mode                = "none"
  create_internet_gateway = false

  flow_logs = { s3_bucket_arn = module.vpc_logs[0].bucket_arn }

  tags = var.tags
}

# Endpoint de Secrets Manager en las subredes data: lo necesita la función de rotación de app_runtime,
# que vive en la VPC sin salida a Internet.
module "endpoints" {
  source = "../../../modules/network/vpc-endpoints"
  count  = local.aurora ? 1 : 0

  project         = var.project
  environment     = var.environment
  vpc_id          = module.vpc[0].vpc_id
  vpc_cidr_block  = module.vpc[0].vpc_cidr_block
  subnet_ids      = module.vpc[0].subnet_ids["data"]
  route_table_ids = module.vpc[0].route_table_ids["data"]

  interface_services = ["secretsmanager"]
  gateway_services   = []

  allowed_security_group_ids = { rotation = module.aurora[0].rotation_security_group_id }

  tags = var.tags
}

module "aurora" {
  source = "../../../modules/data/aurora-postgresql"
  count  = local.aurora ? 1 : 0

  project        = var.project
  environment    = var.environment
  vpc_id         = module.vpc[0].vpc_id
  subnet_ids     = module.vpc[0].subnet_ids["data"]
  az_names       = var.aurora.az_names
  kms_key_arn    = module.kms.key_arn
  engine_version = var.aurora.engine_version

  capacity_mode = "serverless_v2"
  serverless_v2 = {
    min_capacity             = local.aurora_min_capacity
    max_capacity             = var.aurora.max_capacity
    seconds_until_auto_pause = local.aurora_min_capacity == 0 ? 300 : null
  }

  enable_http_endpoint = true
  backup_plan          = local.tier
  skip_final_snapshot  = !local.prod
  apply_immediately    = !local.prod
  monitoring_interval  = local.prod ? 60 : 0
  log_retention_days   = local.log_retention_days

  app_secret_rotation = {
    subnet_ids                 = module.vpc[0].subnet_ids["data"]
    endpoint_security_group_id = module.endpoints[0].security_group_id
  }
  app_secret_recovery_window_in_days = local.prod ? null : 0

  tags = var.tags
}

module "backup_kms" {
  source = "../../../modules/foundation/kms-key"

  project                 = var.project
  environment             = var.environment
  purpose                 = "backup"
  deletion_window_in_days = local.prod ? 30 : 7

  service_principals = ["backup.amazonaws.com"]
  via_services       = ["backup.${local.region}.amazonaws.com"]

  tags = var.tags
}

module "backup" {
  source = "../../../modules/resilience/backup-plan"

  project       = var.project
  environment   = var.environment
  kms_key_arn   = module.backup_kms.key_arn
  tier          = local.tier
  schedule      = local.backup_schedule
  alarm_actions = [module.alarms.topic_arn]

  tags = var.tags
}
