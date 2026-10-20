# Acceso de soporte del proveedor (tercero): ExternalId + MFA + solo lectura, revocable borrando el rol.
# Para que el ejemplo se aplique en una sola cuenta, el rol "de origen" se crea aquí; en un cliente real es
# un rol de la cuenta del proveedor.
provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

data "aws_iam_policy_document" "source_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM valida que los principals de una trust policy existan: el rol de origen debe crearse antes.
resource "aws_iam_role" "source" {
  name               = "acme-${var.name_suffix}-provider-support"
  assume_role_policy = data.aws_iam_policy_document.source_trust.json
}

module "provider_access" {
  source = "../.."

  project           = "acme"
  environment       = "dev"
  name              = "provider-${var.name_suffix}"
  trusted_role_arns = [aws_iam_role.source.arn]

  external_id          = "acme-support-2026"
  require_mfa          = true
  allow_tag_session    = true
  max_session_duration = 3600

  managed_policy_arns = {
    readonly = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  }

  inline_policies = {
    deny-secrets = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "NoSecretValues"
        Effect   = "Deny"
        Action   = ["secretsmanager:GetSecretValue", "ssm:GetParameter*", "kms:Decrypt"]
        Resource = ["*"]
      }]
    })
  }

  tags = {
    Owner = "platform"
  }
}

output "role_arn" {
  description = "ARN del rol de acceso del proveedor."
  value       = module.provider_access.role_arn
}
