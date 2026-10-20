provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "api"

  service_principals = ["logs.us-east-1.amazonaws.com"]
}

module "tenants" {
  source = "../../../../identity/cognito-user-pool"

  project     = "acme"
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

  project       = "acme"
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "acme-dev-rest-artifacts-${data.aws_caller_identity.current.account_id}"
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

  project     = "acme"
  environment = "dev"
  name        = "api"
  kms_key_arn = module.kms.key_arn

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = module.artifacts.bucket_id
  s3_key            = aws_s3_object.package.key
  s3_object_version = aws_s3_object.package.version_id
}

# Sin planes de uso ni WAF (solo dev): token de Cognito en todos los métodos.
module "api" {
  source = "../.."

  project                = "acme"
  environment            = "dev"
  kms_key_arn            = module.kms.key_arn
  lambda_function_arn    = module.backend.function_arn
  cognito_user_pool_arns = [module.tenants.user_pool_arn]

  api_key_required       = false
  publish_ssm_parameters = false
}

output "invoke_url" {
  description = "URL de la etapa."
  value       = module.api.invoke_url
}
