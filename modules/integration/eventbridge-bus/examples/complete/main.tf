provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "data"

  service_principals = ["logs.us-east-1.amazonaws.com", "events.amazonaws.com", "sqs.amazonaws.com"]
  via_services = [
    "s3.us-east-1.amazonaws.com",
    "firehose.us-east-1.amazonaws.com",
  ]
}

module "bucket" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "data"
  kms_key_arn   = module.kms.key_arn
  force_destroy = true # solo porque es un ejemplo efímero
}

module "firehose_orders" {
  source = "../../../firehose-to-s3"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "orders"
  bucket_arn  = module.bucket.bucket_arn
  kms_key_arn = module.kms.key_arn
  prefix      = "orders/"

  publish_ssm_parameters = false
}

module "firehose_usage" {
  source = "../../../firehose-to-s3"

  project      = "acme-${var.name_suffix}"
  environment  = "dev"
  name         = "usage"
  bucket_arn   = module.bucket.bucket_arn
  kms_key_arn  = module.kms.key_arn
  prefix       = "usage/"
  error_prefix = "usage-errors/"

  buffer               = { interval_seconds = 120, size_mb = 64 }
  dynamic_partitioning = { key_name = "tenant_id", jq_query = ".detail.tenant_id" }

  publish_ssm_parameters = false
}

module "events" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  kms_key_arn = module.kms.key_arn

  archive_retention_days = 14

  rules = {
    orders = {
      description     = "Eventos de pedidos (E-commerce)"
      source_prefixes = ["orders."]
      firehose_arn    = module.firehose_orders.delivery_stream_arn
    }
    usage = {
      description          = "Eventos de uso (SaaS)"
      detail_type_prefixes = ["usage."]
      firehose_arn         = module.firehose_usage.delivery_stream_arn
    }
  }

  retry_policy           = { maximum_retry_attempts = 20, maximum_event_age_in_seconds = 3600 }
  dlq_retention_days     = 14
  target_kms_key_arns    = [module.kms.key_arn]
  publish_ssm_parameters = true
}

output "bus_name" {
  description = "Nombre del bus."
  value       = module.events.bus_name
}

output "dlq_arns" {
  description = "ARN de las DLQ por regla."
  value       = module.events.dlq_arns
}
