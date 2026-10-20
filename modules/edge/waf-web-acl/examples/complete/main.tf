provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

# Web ACL regional (p. ej. para el stage de una REST API) con todas las opciones activadas.
module "waf" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "prod"
  scope       = "REGIONAL"

  managed_rules_mode           = "block"
  count_size_restrictions_body = true
  rate_limit_per_5m            = 1000
  enable_bot_control           = true
  anonymous_ip_list_mode       = "count"

  anti_ddos = {
    challenge_sensitivity = "MEDIUM"
  }

  tenant_rate_limit = {
    header_name = "x-tenant-id"
    limit       = 500
  }

  origin_verify = {
    header_name = "x-origin-verify"
    secret      = "valor-de-prueba-no-secreto" # solo para el ejemplo; en real viene de un secreto rotado
  }

  log_retention_days = 365

  tags = {
    Owner = "platform"
  }
}

output "web_acl_arn" {
  description = "ARN del Web ACL."
  value       = module.waf.web_acl_arn
}
