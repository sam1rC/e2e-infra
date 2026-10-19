provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de roles de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }
}

# KMS rechaza key policies con principals inexistentes: el ejemplo crea los suyos.
resource "aws_iam_role" "admin" {
  name               = "kms-example-admin-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role" "app" {
  name               = "kms-example-app-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

module "kms" {
  source = "../.."

  project     = "acme"
  environment = "prod"
  purpose     = "data"
  description = "CMK de datos de producción"

  deletion_window_in_days = 30
  multi_region            = false

  admin_principal_arns = [aws_iam_role.admin.arn]
  user_principal_arns  = [aws_iam_role.app.arn]
  service_principals   = ["logs.us-east-1.amazonaws.com"]
  via_services         = ["s3.us-east-1.amazonaws.com", "rds.us-east-1.amazonaws.com"]

  tags = {
    Owner = "platform"
  }
}

output "key_arn" {
  description = "ARN de la clave."
  value       = module.kms.key_arn
}

output "alias_name" {
  description = "Alias de la clave."
  value       = module.kms.alias_name
}
