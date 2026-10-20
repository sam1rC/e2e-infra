provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "ecr"
}

# Roles de ejemplo en la misma cuenta; en la práctica son el rol OIDC de CI y los roles de ejecución
# de ECS de otras cuentas. ECR rechaza políticas que nombran roles que no existen.
data "aws_iam_policy_document" "ci_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ci" {
  name               = "acme-dev-ci-push-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ci_assume.json
}

resource "aws_iam_role" "pull" {
  name               = "acme-dev-ecs-exec-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ci_assume.json
}

module "ecr" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  name        = "web-${var.name_suffix}"
  kms_key_arn = module.kms.key_arn

  scan_type                = "enhanced"
  manage_registry_scanning = false # en la cuenta real se activa en UNA instancia
  keep_last_images         = 20
  untagged_expiry_days     = 7

  ci_principal_arns   = [aws_iam_role.ci.arn]
  pull_principal_arns = [aws_iam_role.pull.arn]

  force_delete = true # solo porque es un ejemplo efímero
}

output "repository_url" {
  description = "URL del repositorio."
  value       = module.ecr.repository_url
}
