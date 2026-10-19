provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para el nombre del proyecto en pruebas (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "target_id" {
  description = "ID de la OU de pruebas a la que se adjuntan las políticas (en la cuenta de management del sandbox)."
  type        = string
  default     = "ou-abcd-12345678"
  nullable    = false
}

variable "organization_id" {
  description = "ID de la organización de pruebas."
  type        = string
  default     = "o-abcde12345"
  nullable    = false
}

# Atención: las SCP/RCP se aplican a toda la OU de destino. Usa una OU de pruebas vacía.
module "guardrails" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "prod"
  target_ids  = [var.target_id]

  admin_role_arns = [
    "arn:aws:iam::*:role/AWSControlTowerExecution",
    "arn:aws:iam::*:role/gha-apply-prod",
    "arn:aws:iam::*:role/break-glass-*",
  ]
  bootstrap_role_arns = ["arn:aws:iam::*:role/break-glass-*"]

  allowed_regions = ["us-east-1", "us-west-2"]

  state_bucket_arns  = ["arn:aws:s3:::acme-prod-tfstate-123456789012"]
  state_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"]

  enable_resource_control_policies = true
  organization_id                  = var.organization_id

  tags = {
    Owner = "platform"
  }
}

output "security_policy_id" {
  description = "ID de la SCP de seguridad."
  value       = module.guardrails.security_policy_id
}

output "region_policy_id" {
  description = "ID de la SCP de regiones."
  value       = module.guardrails.region_policy_id
}
