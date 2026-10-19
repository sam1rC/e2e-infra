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
  purpose     = "identity"

  # Log groups de Cognito y de la Lambda.
  service_principals = ["logs.us-east-1.amazonaws.com"]
}

# Trigger pre token generation (V2_0): copia custom:tenant_id al access token como claim tenant_id.
module "artifacts" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "acme-dev-identity-${data.aws_caller_identity.current.account_id}-${var.name_suffix}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = []
}

# app.py (código en el README del módulo), empaquetado para que el ejemplo se aplique sin pipeline.
resource "aws_s3_object" "pre_token" {
  bucket         = module.artifacts.bucket_id
  key            = "pre-token/example.zip"
  content_base64 = "UEsDBBQAAAAIAAAAIQC86JcYJwEAAB4CAAAGAAAAYXBwLnB5hZBNa8MwDIbv/RXCu7QQ+gMCO4QVRk8drLdShhqrnZkjZbZc9kH/++K4y9gu08nWx/O+kqUjPCNbT2FOZ2KtoBVWetNFPYMhbuBOeofQpqjS1UqMrE/OwtxxlxQPnirwAhjdiRHIg/BBMFjHpwWgB2xbihFUXojhPWfWq/K78lvpBFqProOJXkGPAeE1EXiE5mGdJTwh2EGgoHLtjN5ZhJgAk0pwH2glLEduQcEtjFvtTKBhIKrZ70yKFBrV4A5JKZr98kQ6N38XNIuR445XVDlHjtFrHNCfpjy30li7CZszheAsmXqo/HDqK+BymQiTp9gLR8qmCqlh+9hKT9+oFSk6P3jMatN4DlPuus23uCemgOqEB7ECqn43O/t/Y7EXSFPg4nD2BVBLAQIUAxQAAAAIAAAAIQC86JcYJwEAAB4CAAAGAAAAAAAAAAAAAACkAQAAAABhcHAucHlQSwUGAAAAAAEAAQA0AAAASwEAAAAA"
  kms_key_id     = module.kms.key_arn
}

module "pre_token" {
  source = "../../../../compute/lambda-function"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "pre-token"
  kms_key_arn = module.kms.key_arn

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = module.artifacts.bucket_id
  s3_key            = aws_s3_object.pre_token.key
  s3_object_version = aws_s3_object.pre_token.version_id

  timeout_seconds    = 5
  log_retention_days = 30
}

# Pool de tenants (SaaS): plan PLUS con threat protection, tenant inmutable, grupo de administradores,
# managed login con prefijo y trigger para el access token.
module "tenants" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "tenants"
  kms_key_arn = module.kms.key_arn

  feature_plan        = "PLUS"
  tenant_id_attribute = true

  password_policy = {
    minimum_length        = 16
    password_history_size = 10
  }

  groups = {
    admins = { description = "Administradores del tenant", precedence = 1 }
    users  = { description = "Usuarios del tenant", precedence = 10 }
  }

  app_clients = {
    web = {
      callback_urls                 = ["https://app.example.com/callback", "http://localhost:3000/callback"]
      logout_urls                   = ["https://app.example.com/"]
      access_token_validity_minutes = 15
      read_attributes               = ["email", "email_verified", "name", "custom:tenant_id"]
    }
  }

  domain = { prefix = "acme-${var.name_suffix}-tenants" }

  threat_protection = {
    mode          = "ENFORCED"
    medium_action = "MFA_REQUIRED"
    high_action   = "BLOCK"
  }

  pre_token_generation_lambda_arn = module.pre_token.function_arn
  pre_token_generation_enabled    = true # la Lambda se crea en este mismo apply

  deletion_protection = false
  log_retention_days  = 30

  tags = {
    Owner = "platform"
  }
}

output "user_pool_id" {
  description = "ID del user pool."
  value       = module.tenants.user_pool_id
}

output "issuer_url" {
  description = "Emisor de los JWT."
  value       = module.tenants.issuer_url
}

output "client_ids" {
  description = "IDs de los app clients."
  value       = module.tenants.client_ids
}

output "domain_url" {
  description = "URL de managed login."
  value       = module.tenants.domain_url
}
