provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

data "aws_caller_identity" "current" {}

# Bucket de flow logs. Los flow logs entregan con delivery.logs.amazonaws.com; este ejemplo usa SSE-S3
# para no tener que autorizar a ese servicio en una CMK.
module "flow_logs_bucket" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "logs"
  sse_algorithm = "AES256"
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = [
    {
      sid            = "AWSLogDeliveryWrite"
      actions        = ["s3:PutObject"]
      resource_paths = ["/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions = [
        { test = "StringEquals", variable = "s3:x-amz-acl", values = ["bucket-owner-full-control"] },
        { test = "StringEquals", variable = "aws:SourceAccount", values = [data.aws_caller_identity.current.account_id] },
      ]
    },
    {
      sid            = "AWSLogDeliveryAclCheck"
      actions        = ["s3:GetBucketAcl", "s3:ListBucket"]
      resource_paths = [""]
      principals     = [{ type = "Service", identifiers = ["delivery.logs.amazonaws.com"] }]
      conditions     = [{ test = "StringEquals", variable = "aws:SourceAccount", values = [data.aws_caller_identity.current.account_id] }]
    },
  ]
}

# CMK propia (no alias/aws/sns): CloudWatch publica las alarmas con su principal de servicio.
module "alarms_kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "alarms"

  service_principals = ["sns.amazonaws.com", "cloudwatch.amazonaws.com"]
}

resource "aws_sns_topic" "alarms" {
  name              = "acme-${var.name_suffix}-network-alarms"
  kms_master_key_id = module.alarms_kms.key_arn
}

# Configuración de producción por defecto: NAT regional, sin subredes públicas.
module "vpc" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.30.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b", "us-east-1c"]

  nat_mode                = "regional"
  create_internet_gateway = true
  subnet_tiers            = { public = false, app = true, data = true }
  subnet_newbits          = 4
  data_tier_ports         = [5432, 6379]

  flow_logs = {
    s3_bucket_arn            = module.flow_logs_bucket.bucket_arn
    traffic_type             = "ALL"
    max_aggregation_interval = 600
  }

  alarm_actions          = [aws_sns_topic.alarms.arn]
  publish_ssm_parameters = true

  tags = {
    Owner = "platform"
  }
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.vpc.vpc_id
}

output "nat_gateway_ids" {
  description = "NAT creadas."
  value       = module.vpc.nat_gateway_ids
}
