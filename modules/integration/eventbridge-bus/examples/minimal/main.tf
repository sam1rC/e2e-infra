provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "events"

  service_principals = ["events.amazonaws.com", "sqs.amazonaws.com"]
}

# Solo el bus y su archivo; las reglas hacia Firehose se añaden con rules (ver examples/complete).
module "events" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  kms_key_arn = module.kms.key_arn

  publish_ssm_parameters = false
}

output "bus_name" {
  description = "Nombre del bus."
  value       = module.events.bus_name
}
