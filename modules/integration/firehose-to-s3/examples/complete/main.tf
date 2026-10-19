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

# SaaS: un prefijo por tenant (partición dinámica por .detail.tenant_id).
module "firehose" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "usage"
  bucket_arn  = module.bucket.bucket_arn
  kms_key_arn = module.kms.key_arn

  prefix             = "usage/"
  error_prefix       = "usage-errors/"
  compression_format = "GZIP"
  buffer             = { interval_seconds = 120, size_mb = 64 }

  dynamic_partitioning = {
    key_name = "tenant_id"
    jq_query = ".detail.tenant_id"
  }

  log_retention_days     = 30
  publish_ssm_parameters = true
}

output "delivery_stream_arn" {
  description = "ARN del delivery stream."
  value       = module.firehose.delivery_stream_arn
}

output "object_prefix" {
  description = "Prefijo de los objetos."
  value       = module.firehose.object_prefix
}
