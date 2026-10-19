provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "alarms"

  service_principals = ["cloudwatch.amazonaws.com", "sns.amazonaws.com"]
}

# Solo el topic cifrado; las alarmas aparecen al declarar los recursos a vigilar (ver examples/complete).
module "alarms" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  kms_key_arn = module.kms.key_arn
}

output "topic_arn" {
  description = "ARN del topic de alarmas."
  value       = module.alarms.topic_arn
}
