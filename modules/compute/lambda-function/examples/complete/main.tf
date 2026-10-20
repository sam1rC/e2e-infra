provider "aws" {
  region = "us-east-1"
}

variable "reserved_concurrency" {
  description = "Concurrencia reservada de la función. null = sin reserva: las cuentas nuevas tienen una cuota de 10 ejecuciones concurrentes y AWS exige dejar al menos 10 sin reservar, así que cualquier reserva falla hasta que se amplía la cuota."
  type        = number
  default     = null
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../../../network/vpc"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  cidr_block  = "10.72.0.0/16"
  az_names    = ["us-east-1a", "us-east-1b"]

  nat_mode               = "none"
  enable_flow_logs       = false # solo para el ejemplo
  publish_ssm_parameters = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  purpose     = "lambda"

  # CloudWatch Logs cifra el log group; SQS cifra la cola DLQ en nombre de la función.
  service_principals = ["logs.us-east-1.amazonaws.com"]
  via_services       = ["sqs.us-east-1.amazonaws.com"]
}

# Bucket de artefactos (versionado): en la práctica lo llena el pipeline de la aplicación.
module "artifacts" {
  source = "../../../../storage/s3-bucket"

  project       = "acme-${var.name_suffix}"
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "acme-dev-artifacts-${data.aws_caller_identity.current.account_id}-${var.name_suffix}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = true # solo porque es un ejemplo efímero

  policy_statements = []
}

# Paquete mínimo (app.py con un handler) para que el ejemplo se pueda aplicar sin pipeline.
resource "aws_s3_object" "package" {
  bucket         = module.artifacts.bucket_id
  key            = "orders/example.zip"
  content_base64 = "UEsDBBQAAAAAAAAAIVBNcim7bAAAAGwAAAAGAAAAYXBwLnB5aW1wb3J0IGpzb24KCgpkZWYgaGFuZGxlcihldmVudCwgY29udGV4dCk6CiAgICByZXR1cm4geyJzdGF0dXNDb2RlIjogMjAwLCAiYm9keSI6IGpzb24uZHVtcHMoeyJvayI6IFRydWV9KX0KUEsBAhQDFAAAAAAAAAAhUE1yKbtsAAAAbAAAAAYAAAAAAAAAAAAAAKQBAAAAAGFwcC5weVBLBQYAAAAAAQABADQAAACQAAAAAAA="
  kms_key_id     = module.kms.key_arn
}

resource "aws_security_group" "db" {
  name_prefix = "acme-${var.name_suffix}-db-"
  description = "Destino de ejemplo para la salida de la funcion"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

module "function" {
  source = "../.."

  project     = "acme-${var.name_suffix}"
  environment = "dev"
  name        = "orders"
  kms_key_arn = module.kms.key_arn

  runtime           = "python3.13"
  handler           = "app.handler"
  s3_bucket         = module.artifacts.bucket_id
  s3_key            = aws_s3_object.package.key
  s3_object_version = aws_s3_object.package.version_id

  memory_size     = 512
  timeout_seconds = 15

  environment_variables = {
    TABLE_NAME = "orders"
  }

  log_retention_days    = 30
  application_log_level = "DEBUG"

  reserved_concurrent_executions = var.reserved_concurrency
  enable_dlq                     = true

  vpc_config = {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.vpc.subnet_ids["app"]
    egress_rules = {
      db = { description = "PostgreSQL", port = 5432, security_group_id = aws_security_group.db.id }
    }
  }

  # Permisos de la aplicación, explícitos: leer un único secreto.
  policies = {
    read-secret = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:acme/orders-*"]
      }]
    })
  }
}

output "function_arn" {
  description = "ARN de la función."
  value       = module.function.function_arn
}

output "dlq_arn" {
  description = "ARN de la cola de dead-letter."
  value       = module.function.dlq_arn
}
