provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "create_oidc_provider" {
  description = "Crea el proveedor OIDC de GitHub (único por cuenta). false = reutiliza el que ya exista en la cuenta."
  type        = bool
  default     = false
  nullable    = false
}

module "state_backend" {
  source = "../../../state-backend"

  project     = "acme-${var.name_suffix}"
  environment = "staging"
}

module "github_oidc" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "staging"

  github_org         = "acme-corp"
  github_repo        = "acme-infra"
  github_environment = "staging-approvals"
  main_branch        = "main"

  # Otra prueba o la propia cuenta puede tener ya el proveedor OIDC: por defecto se reutiliza; en una
  # cuenta sin él, la prueba de integración se lanza con -var create_oidc_provider=true.
  create_provider = var.create_oidc_provider
  name_prefix     = "gha-${var.name_suffix}"

  state_bucket_arn  = module.state_backend.bucket_arn
  state_kms_key_arn = module.state_backend.kms_key_arn

  plan_policy_arns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  apply_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]

  tags = {
    Owner = "platform"
  }
}

output "plan_role_arn" {
  description = "ARN del rol de plan."
  value       = module.github_oidc.plan_role_arn
}

output "apply_role_arn" {
  description = "ARN del rol de apply."
  value       = module.github_oidc.apply_role_arn
}
