provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

variable "origin_verify_token" {
  description = "Token de la cabecera x-origin-verify (en real viene de un secreto rotado y lo añade CloudFront; ADR 0010)."
  type        = string
  default     = "valor-de-prueba-no-secreto-0123456789abcdef"
  sensitive   = true
  nullable    = false
}

data "aws_caller_identity" "current" {}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "api"

  service_principals = ["logs.us-east-1.amazonaws.com"]
}

module "tenants" {
  source = "../../../../identity/cognito-user-pool"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "tenants"
  kms_key_arn = module.kms.key_arn

  tenant_id_attribute = true

  app_clients = {
    web = { callback_urls = ["https://app.example.com/callback"] }
  }

  publish_ssm_parameters = false
}

module "artifacts" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "acme-dev-rest-artifacts-${data.aws_caller_identity.current.account_id}-${var.name_suffix}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = []
}

resource "aws_s3_object" "package" {
  bucket         = module.artifacts.bucket_id
  key            = "api/example.zip"
  content_base64 = "UEsDBBQAAAAAAAAAIVBNcim7bAAAAGwAAAAGAAAAYXBwLnB5aW1wb3J0IGpzb24KCgpkZWYgaGFuZGxlcihldmVudCwgY29udGV4dCk6CiAgICByZXR1cm4geyJzdGF0dXNDb2RlIjogMjAwLCAiYm9keSI6IGpzb24uZHVtcHMoeyJvayI6IFRydWV9KX0KUEsBAhQDFAAAAAAAAAAhUE1yKbtsAAAAbAAAAAYAAAAAAAAAAAAAAKQBAAAAAGFwcC5weVBLBQYAAAAAAQABADQAAACQAAAAAAA="
  kms_key_id     = module.kms.key_arn
}

module "backend" {
  source = "../../../../compute/lambda-function"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "api"
  kms_key_arn = module.kms.key_arn

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = module.artifacts.bucket_id
  s3_key            = aws_s3_object.package.key
  s3_object_version = aws_s3_object.package.version_id
}

# WAF regional: bloquea lo que no llegue por CloudFront con la cabecera de verificación de origen.
module "waf" {
  source = "../../../../edge/waf-web-acl"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  scope       = "REGIONAL"

  origin_verify = {
    secret = var.origin_verify_token
  }

  tenant_rate_limit = {
    header_name = "x-api-key"
    limit       = 1000
  }

  log_retention_days = 30
}

module "api" {
  source = "../.."

  project                = "acme-${var.name_suffix}"
  environment            = "dev"
  name                   = "saas"
  kms_key_arn            = module.kms.key_arn
  lambda_function_arn    = module.backend.function_arn
  cognito_user_pool_arns = [module.tenants.user_pool_arn]

  usage_plans = {
    basic = { rate_limit = 10, burst_limit = 20, quota_limit = 100000, description = "Tier basic" }
    pro   = { rate_limit = 100, burst_limit = 200, description = "Tier pro" }
  }

  cors_allow_origin = "https://app.example.com"
  web_acl_arn       = module.waf.web_acl_arn
  web_acl_enabled   = true # el Web ACL se crea en este mismo apply

  throttling = {
    burst_limit = 200
    rate_limit  = 100
  }

  # El rol de CloudWatch de API Gateway es de la cuenta: en la cuenta real, en una sola instancia.
  manage_account_logging_role = true
  log_retention_days          = 30

  tags = {
    Owner = "platform"
  }
}

output "invoke_url" {
  description = "URL de la etapa."
  value       = module.api.invoke_url
}

output "origin_domain_name" {
  description = "Dominio para el origen de CloudFront."
  value       = module.api.origin_domain_name
}

output "usage_plan_ids" {
  description = "Planes de uso por tier."
  value       = module.api.usage_plan_ids
}
