# Composición de prueba del blueprint E-commerce T3 (fixture de tests/integration.tftest.hcl). Equivale a
# lo que genera live/ en la fase 10, con estado local y valores de sandbox.

variable "region" {
  description = "Región de la aplicación."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "account_id" {
  description = "Cuenta sandbox permitida (allowed_account_ids evita aplicar en otra cuenta)."
  type        = string
  nullable    = false
}

variable "name_suffix" {
  description = "Sufijo del proyecto para que las pruebas no colisionen (máx. 8 caracteres)."
  type        = string
  default     = "t3"
  nullable    = false
}

variable "domain_name" {
  description = "Dominio de prueba (subdominio de la zona delegada en la sandbox)."
  type        = string
  nullable    = false
}

variable "zone_id" {
  description = "Zona de Route 53 de la sandbox que contiene domain_name."
  type        = string
  nullable    = false
}

variable "database" {
  description = "dynamodb (barato, por defecto) o aurora_data_api."
  type        = string
  default     = "dynamodb"
  nullable    = false
}

variable "alarm_emails" {
  description = "Correos de las alarmas (opcional en dev)."
  type        = list(string)
  default     = []
  nullable    = false
}

variable "run_id" {
  description = "Identificador de la ejecución (etiqueta RunId para encontrar restos)."
  type        = string
  default     = "manual"
  nullable    = false
}

locals {
  project = "ct-${var.name_suffix}"

  tags = {
    Project            = local.project
    Environment        = "test"
    Owner              = "platform"
    ManagedBy          = "opentofu"
    Blueprint          = "ecommerce-t3"
    CostCenter         = "catalog-test"
    DataClassification = "internal"
    TTL                = "4h"
    RunId              = var.run_id
  }

  # Zip de tests/fixtures/lambda-origin-verify/app.py (ver su README para regenerarlo).
  app_zip_base64 = "UEsDBBQAAAAIAAAAIQBpPtBMAgIAANADAAAGAAAAYXBwLnB5bVLNjtowEL7nKSyfEglS1O0JicMKsVUu7CphqSq0ikw8gLuJHdkmXYTy7p3YJASpvtgzY38/MxZVrbQlp4oVgfDnP0bJ/qxM0B/3yqqnIMhNRRY+iItSgLQhNVBosKZikh1B0yjIrfoEafDiWkkIgoDDgeQNKwW/lcJoHhBcx1LtWUluWZcShz4kwjgAf7VbTEsEVSYG2Qit5I6+psnPZJ1vV2ny8jvPVst0tcmf0zX9GB4Zi7I6MVdDDkqThghJ0EfMwRRa7CH3BsLMbQlfIE20o1vQRiiZcLNRmcOgHzGaOAPKd0imQ2ragenuezfkXB7JjmBvPLnDeGCbkBuZ41kYZPflzGohjyMz3RqoQ/r8K1u+p+lqvaET0kVv6WqbvL5nOIXxE2yqe+F7MZQ8LvKcsbH9EPy4TkzyEnQIDc54QgolLXzZfmzKoklf65yF9ASMowUaERR3bSOf/ZoqLY5CThvQ4nDpNN6EoSCJIExewu7zxYWqaqYh5wL12RAJJsT6Lls3r8ffE93/xE39laI3ezZLxYHOyY/ZE5LtFb9g0H3pmJ+r2oRXWoEx2ARM0xel94JzkLSN2nErrgP6I+r32WxyL/We50ju+iPt1F5qB83quhQFszjTbx09bUcP/ydLfWJmo8+AsmtmTxiN2qvZ37cu6do7yrubURt58Db4B1BLAQIUAxQAAAAIAAAAIQBpPtBMAgIAANADAAAGAAAAAAAAAAAAAACkAQAAAABhcHAucHlQSwUGAAAAAAEAAQA0AAAAJgIAAAAA"
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}

# Artefacto de la Lambda: en un cliente lo sube su pipeline; aquí, un bucket efímero con el handler de prueba.
module "artifacts" {
  source = "../../../../modules/storage/s3-bucket"

  project       = local.project
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "${local.project}-dev-artifacts-${var.account_id}"
  sse_algorithm = "AES256"
  force_destroy = true # solo porque es un ejemplo efímero
}

resource "aws_s3_object" "package" {
  bucket         = module.artifacts.bucket_id
  key            = "api/app.zip"
  content_base64 = local.app_zip_base64
}

module "stack" {
  source = "../../stack"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project     = local.project
  environment = "dev"
  domain_name = var.domain_name
  zone_id     = var.zone_id
  database    = var.database

  aurora = {
    az_names = ["${var.region}a", "${var.region}b"]
  }

  api_function = {
    s3_bucket         = module.artifacts.bucket_id
    s3_key            = aws_s3_object.package.key
    s3_object_version = aws_s3_object.package.version_id
  }

  # Ruta pública para comprobar la verificación de origen sin token; el resto exige JWT.
  api_routes = {
    "GET /api/health"   = { authorization = "NONE" }
    "ANY /api/{proxy+}" = {}
  }

  alarm_emails = var.alarm_emails

  # En dev el WAF va en count; la prueba bloquea para comprobar el 403 de una SQLi.
  waf_rules_mode = "block"
}

output "url" {
  description = "URL pública de la tienda."
  value       = "https://${var.domain_name}"
}

output "distribution_domain_name" {
  description = "Dominio de CloudFront."
  value       = module.stack.distribution_domain_name
}

output "api_endpoint" {
  description = "Endpoint directo de la API (debe responder 403 sin la cabecera de CloudFront)."
  value       = module.stack.api_endpoint
}

output "site_bucket_id" {
  description = "Bucket del frontend."
  value       = module.stack.site_bucket_id
}

output "backup_vault_name" {
  description = "Vault de backup (vaciar recovery points antes del destroy)."
  value       = module.stack.backup_vault_name
}
