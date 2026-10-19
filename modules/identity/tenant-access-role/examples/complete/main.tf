provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "test_principal_arns" {
  description = "Principals que pueden asumir el rol de la aplicación de ejemplo (p. ej. el usuario o rol que ejecuta tests/integration/tenant-isolation). Vacío = solo Lambda."
  type        = list(string)
  default     = []
  nullable    = false
}

data "aws_iam_policy_document" "app_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

  # Solo para la prueba de aislamiento: el ejecutor actúa como la aplicación (encadenamiento de roles).
  dynamic "statement" {
    for_each = length(var.test_principal_arns) > 0 ? [1] : []

    content {
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = var.test_principal_arns
      }
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "acme-${var.name_suffix}-dev-api"
  assume_role_policy = data.aws_iam_policy_document.app_assume.json
}

# La aplicación solo puede asumir el rol del tenant pasando la etiqueta de sesión.
data "aws_iam_policy_document" "app_vend" {
  statement {
    actions   = ["sts:AssumeRole", "sts:TagSession"]
    resources = [module.tenant_access.role_arn]
  }
}

resource "aws_iam_role_policy" "app_vend" {
  name   = "assume-tenant-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_vend.json
}

module "kms_data" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "data"

  via_services = ["dynamodb.us-east-1.amazonaws.com", "s3.us-east-1.amazonaws.com"]
}

# Clave para cifrado en la aplicación con contexto por tenant (envelope encryption).
module "kms_tenant" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "tenant"
}

module "orders" {
  source = "../../../../data/dynamodb-table"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "orders"
  kms_key_arn = module.kms_data.key_arn

  tenant_partition_key = true
  hash_key             = "tenant_id"
  range_key            = "order_id"
  attributes           = { tenant_id = "S", order_id = "S", status = "S" }

  global_secondary_indexes = {
    by-status = { hash_key = "tenant_id", range_key = "status" }
  }

  deletion_protection    = false
  publish_ssm_parameters = false
}

module "documents" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "data"
  kms_key_arn   = module.kms_data.key_arn
  force_destroy = true # solo porque es un ejemplo efímero
}

module "tenant_access" {
  source = "../.."

  project           = "acme-${var.name_suffix}"
  environment       = "dev"
  trusted_role_arns = [aws_iam_role.app.arn]

  dynamodb_tables = {
    orders = { table_arn = module.orders.table_arn }
  }

  s3_buckets = {
    documents = {
      bucket_arn  = module.documents.bucket_arn
      prefix      = "tenants/"
      kms_key_arn = module.kms_data.key_arn
    }
  }

  kms_keys = {
    envelope = module.kms_tenant.key_arn
  }

  tags = {
    Owner = "platform"
  }
}

output "app_role_arn" {
  description = "ARN del rol de la aplicación de ejemplo."
  value       = aws_iam_role.app.arn
}

output "role_arn" {
  description = "ARN del rol de acceso del tenant."
  value       = module.tenant_access.role_arn
}

output "table_name" {
  description = "Tabla en modo pool."
  value       = module.orders.table_name
}

output "bucket_name" {
  description = "Bucket con un prefijo por tenant."
  value       = module.documents.bucket_id
}
