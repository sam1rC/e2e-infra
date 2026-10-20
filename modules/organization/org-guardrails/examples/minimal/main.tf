provider "aws" {
  region = "us-east-1"
}

module "guardrails" {
  source = "../.."

  project         = "acme"
  environment     = "dev"
  target_ids      = ["ou-abcd-12345678"]
  admin_role_arns = ["arn:aws:iam::*:role/AWSControlTowerExecution"]
  allowed_regions = ["us-east-1", "us-west-2"]
}

output "security_policy_id" {
  description = "ID de la SCP de seguridad."
  value       = module.guardrails.security_policy_id
}
