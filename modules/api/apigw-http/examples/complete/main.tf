provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
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

# Clientes de la tienda (E-commerce T3): emisor y audiencia del autorizador JWT.
module "customers" {
  source = "../../../../identity/cognito-user-pool"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "customers"
  kms_key_arn = module.kms.key_arn

  self_registration_enabled = true

  app_clients = {
    web = { callback_urls = ["https://shop.example.com/callback"] }
  }

  publish_ssm_parameters = false
}

module "artifacts" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "acme-dev-api-artifacts-${data.aws_caller_identity.current.account_id}-${var.name_suffix}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = []
}

# Paquete mínimo (app.py que responde 200) para aplicar el ejemplo sin pipeline.
resource "aws_s3_object" "package" {
  bucket         = module.artifacts.bucket_id
  key            = "api/example.zip"
  content_base64 = "UEsDBBQAAAAAAAAAIVBNcim7bAAAAGwAAAAGAAAAYXBwLnB5aW1wb3J0IGpzb24KCgpkZWYgaGFuZGxlcihldmVudCwgY29udGV4dCk6CiAgICByZXR1cm4geyJzdGF0dXNDb2RlIjogMjAwLCAiYm9keSI6IGpzb24uZHVtcHMoeyJvayI6IFRydWV9KX0KUEsBAhQDFAAAAAAAAAAhUE1yKbtsAAAAbAAAAAYAAAAAAAAAAAAAAKQBAAAAAGFwcC5weVBLBQYAAAAAAQABADQAAACQAAAAAAA="
  kms_key_id     = module.kms.key_arn
}

module "orders" {
  source = "../../../../compute/lambda-function"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "orders"
  kms_key_arn = module.kms.key_arn

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = module.artifacts.bucket_id
  s3_key            = aws_s3_object.package.key
  s3_object_version = aws_s3_object.package.version_id

  # La función valida la cabecera x-origin-verify (HTTP API no admite WAF): ver README del módulo de API.
  environment_variables = {
    ORIGIN_VERIFY_HEADER = "x-origin-verify"
  }
}

module "catalog" {
  source = "../../../../compute/lambda-function"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "catalog"
  kms_key_arn = module.kms.key_arn

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = module.artifacts.bucket_id
  s3_key            = aws_s3_object.package.key
  s3_object_version = aws_s3_object.package.version_id
}

module "api" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "shop"
  kms_key_arn = module.kms.key_arn

  integrations = {
    orders  = { lambda_function_arn = module.orders.function_arn, timeout_milliseconds = 10000 }
    catalog = { lambda_function_arn = module.catalog.function_arn, timeout_milliseconds = 5000 }
  }

  routes = {
    "GET /products"       = { integration = "catalog", authorization = "NONE", throttling_rate_limit = 200, throttling_burst_limit = 400 }
    "GET /orders"         = { integration = "orders" }
    "POST /orders"        = { integration = "orders", throttling_rate_limit = 10, throttling_burst_limit = 20 }
    "GET /orders/{id}"    = { integration = "orders", scopes = ["openid"] }
    "DELETE /orders/{id}" = { integration = "orders", scopes = ["openid"] }
  }

  jwt_authorizer = {
    issuer   = module.customers.issuer_url
    audience = values(module.customers.client_ids)
  }

  cors = {
    allow_origins = ["https://shop.example.com", "http://localhost:3000"]
  }

  throttling = {
    burst_limit = 50
    rate_limit  = 25
  }

  log_retention_days = 30

  tags = {
    Owner = "platform"
  }
}

output "api_endpoint" {
  description = "Endpoint de la API."
  value       = module.api.api_endpoint
}

output "origin_domain_name" {
  description = "Dominio para el origen de CloudFront."
  value       = module.api.origin_domain_name
}
