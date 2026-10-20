# trivy:ignore:AWS-0030 Con scan_type = "enhanced" el escaneo lo hace Amazon Inspector a nivel de registro (manage_registry_scanning) y scan_on_push es false por diseño; con "basic" es true.
resource "aws_ecr_repository" "this" {
  name                 = local.repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    # Con escaneo enhanced lo gobierna el registro (Inspector); el escaneo básico al subir es el respaldo.
    scan_on_push = var.scan_type == "basic"
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(var.tags, { Name = local.repository_name })
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = jsonencode(local.lifecycle_policy)
}

# Registro único por cuenta y región: ver manage_registry_scanning.
resource "aws_ecr_registry_scanning_configuration" "this" {
  count = var.scan_type == "enhanced" && var.manage_registry_scanning ? 1 : 0

  scan_type = "ENHANCED"

  rule {
    scan_frequency = "CONTINUOUS_SCAN"

    repository_filter {
      filter      = "${var.project}-${var.environment}-*"
      filter_type = "WILDCARD"
    }
  }
}

# Las políticas de repositorio de ECR no admiten el elemento Resource (el recurso es el propio repositorio):
# con él, SetRepositoryPolicy falla con "Invalid repository policy provided" (comprobado en la cuenta sandbox).
data "aws_iam_policy_document" "repository" {
  count = local.create_policy ? 1 : 0

  dynamic "statement" {
    for_each = length(var.ci_principal_arns) > 0 ? [1] : []

    content {
      sid     = "CiPushPull"
      effect  = "Allow"
      actions = concat(local.push_actions, ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"])

      principals {
        type        = "AWS"
        identifiers = var.ci_principal_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.pull_principal_arns) > 0 ? [1] : []

    content {
      sid     = "PullOnly"
      effect  = "Allow"
      actions = local.pull_actions

      principals {
        type        = "AWS"
        identifiers = var.pull_principal_arns
      }
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  count = local.create_policy ? 1 : 0

  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.repository[0].json
}
