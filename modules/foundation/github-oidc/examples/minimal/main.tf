provider "aws" {
  region = "us-east-1"
}

module "state_backend" {
  source = "../../../state-backend"

  project     = "acme"
  environment = "dev"
}

module "github_oidc" {
  source = "../.."

  project     = "acme"
  environment = "dev"

  github_org  = "acme-corp"
  github_repo = "acme-infra"

  state_bucket_arn  = module.state_backend.bucket_arn
  state_kms_key_arn = module.state_backend.kms_key_arn
}

output "plan_role_arn" {
  description = "ARN del rol de plan."
  value       = module.github_oidc.plan_role_arn
}

output "apply_role_arn" {
  description = "ARN del rol de apply."
  value       = module.github_oidc.apply_role_arn
}
