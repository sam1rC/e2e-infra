provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "identity"

  service_principals = ["logs.us-east-1.amazonaws.com"]
}

# Pool de clientes de una tienda (E-commerce T3): registro libre, plan ESSENTIALS y un cliente SPA.
module "customers" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  name        = "customers"
  kms_key_arn = module.kms.key_arn

  self_registration_enabled = true

  app_clients = {
    web = { callback_urls = ["https://shop.example.com/callback", "http://localhost:3000/callback"] }
  }

  publish_ssm_parameters = false
}

output "issuer_url" {
  description = "Emisor de los JWT."
  value       = module.customers.issuer_url
}

output "client_ids" {
  description = "IDs de los app clients."
  value       = module.customers.client_ids
}
