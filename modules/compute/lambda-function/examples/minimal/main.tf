provider "aws" {
  region = "us-east-1"
}

variable "s3_bucket" {
  description = "Bucket con el paquete zip de la función (lo sube el pipeline de la aplicación)."
  type        = string
  default     = "acme-dev-artifacts-123456789012"
  nullable    = false
}

variable "s3_key" {
  description = "Clave del paquete zip."
  type        = string
  default     = "orders/1.0.0.zip"
  nullable    = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "lambda"

  service_principals = ["logs.us-east-1.amazonaws.com"]
}

module "function" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  name        = "orders"
  kms_key_arn = module.kms.key_arn

  runtime   = "python3.13"
  handler   = "app.handler"
  s3_bucket = var.s3_bucket
  s3_key    = var.s3_key
}

output "function_arn" {
  description = "ARN de la función."
  value       = module.function.function_arn
}
