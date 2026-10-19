provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "data"

  via_services = ["dynamodb.us-east-1.amazonaws.com"]
}

# Pay-per-request, PITR y SSE con la CMK por defecto.
module "table" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  name        = "sessions"
  kms_key_arn = module.kms.key_arn

  hash_key   = "pk"
  attributes = { pk = "S" }

  publish_ssm_parameters = false
}

output "table_name" {
  description = "Nombre de la tabla."
  value       = module.table.table_name
}
