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

  via_services = ["dynamodb.us-east-1.amazonaws.com"]
}

# Tabla multi-tenant: la clave de partición es tenant_id (aislamiento por dynamodb:LeadingKeys, fase 8.3).
module "orders" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "orders"
  kms_key_arn = module.kms.key_arn

  tenant_partition_key = true
  hash_key             = "tenant_id"
  range_key            = "order_id"

  attributes = {
    tenant_id  = "S"
    order_id   = "S"
    status     = "S"
    created_at = "N"
    channel    = "S"
  }

  global_secondary_indexes = {
    by-status = { hash_key = "tenant_id", range_key = "status", projection_type = "INCLUDE", non_key_attributes = ["total"] }
    by-date   = { hash_key = "tenant_id", range_key = "created_at" }
  }

  local_secondary_indexes = {
    by-channel = { range_key = "channel", projection_type = "KEYS_ONLY" }
  }

  table_class                 = "STANDARD"
  point_in_time_recovery_days = 14
  deletion_protection         = false
  ttl_attribute               = "expires_at"
  stream_view_type            = "NEW_AND_OLD_IMAGES"
  enable_contributor_insights = true
}

output "table_name" {
  description = "Nombre de la tabla."
  value       = module.orders.table_name
}

output "iam_resource_arns" {
  description = "Recursos IAM de la tabla y sus índices."
  value       = module.orders.iam_resource_arns
}

output "stream_arn" {
  description = "ARN del stream."
  value       = module.orders.stream_arn
}
