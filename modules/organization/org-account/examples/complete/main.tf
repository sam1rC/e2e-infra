# Requiere la cuenta de management de una organización de pruebas. Crear una cuenta real es lento
# (minutos) y cerrarla deja la cuenta suspendida 90 días: ver tests/integration.tftest.hcl.
provider "aws" {
  region = "us-east-1"
}

variable "parent_id" {
  description = "OU de pruebas donde se crea la cuenta."
  type        = string
  default     = "ou-abcd-12345678"
  nullable    = false
}

variable "email" {
  description = "Correo raíz único para la cuenta de prueba."
  type        = string
  default     = "aws+acme-silo-tenant1@example.com"
  nullable    = false
}

module "account" {
  source = "../.."

  project     = "acme"
  environment = "prod"
  account_key = "silo-tenant1"
  name        = "acme-silo-tenant1"
  email       = var.email
  parent_id   = var.parent_id

  role_name                  = "OrganizationAccountAccessRole"
  iam_user_access_to_billing = "DENY"
  close_on_deletion          = false

  tags = {
    Tenant = "tenant1"
    Tier   = "premium"
  }
}

output "account_id" {
  description = "ID de la cuenta."
  value       = module.account.account_id
}

output "bootstrap_role_arn" {
  description = "Rol de bootstrap para aplicar account-baseline en la cuenta nueva."
  value       = module.account.bootstrap_role_arn
}
