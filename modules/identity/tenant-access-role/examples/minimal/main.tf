provider "aws" {
  region = "us-east-1"
}

# Rol de ejecución de la aplicación (en un blueprint, el task role de ECS o el rol de la Lambda).
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "acme-dev-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "data"

  via_services = ["dynamodb.us-east-1.amazonaws.com"]
}

# Tabla en modo pool: la clave de partición es exactamente tenant_id (ADR 0006).
module "orders" {
  source = "../../../../data/dynamodb-table"

  project     = "acme"
  environment = "dev"
  name        = "orders"
  kms_key_arn = module.kms.key_arn

  tenant_partition_key = true
  hash_key             = "tenant_id"
  range_key            = "order_id"
  attributes           = { tenant_id = "S", order_id = "S" }

  publish_ssm_parameters = false
}

module "tenant_access" {
  source = "../.."

  project           = "acme"
  environment       = "dev"
  trusted_role_arns = [aws_iam_role.app.arn]

  dynamodb_tables = {
    orders = { table_arn = module.orders.table_arn }
  }
}

output "role_arn" {
  description = "ARN del rol que asume la aplicación con la etiqueta del tenant."
  value       = module.tenant_access.role_arn
}
