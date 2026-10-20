provider "aws" {
  region = "us-east-1"
}

module "baseline" {
  source = "../.."

  project      = "acme"
  environment  = "dev"
  alert_emails = ["security@example.com"]
}

output "alerts_topic_arn" {
  description = "Tópico SNS de alertas de seguridad."
  value       = module.baseline.alerts_topic_arn
}
