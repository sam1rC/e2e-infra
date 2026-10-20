locals {
  repository_name = "${var.project}-${var.environment}-${var.name}"

  # El orden importa: la regla "any" debe tener la prioridad numérica más alta (se evalúa la última).
  lifecycle_policy = {
    rules = [
      {
        rulePriority = 1
        description  = "Expira las imagenes sin etiqueta tras ${var.untagged_expiry_days} dias"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Conserva las ultimas ${var.keep_last_images} imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_last_images
        }
        action = { type = "expire" }
      },
    ]
  }

  push_actions = [
    "ecr:BatchCheckLayerAvailability",
    "ecr:CompleteLayerUpload",
    "ecr:InitiateLayerUpload",
    "ecr:PutImage",
    "ecr:UploadLayerPart",
  ]

  pull_actions = [
    "ecr:BatchCheckLayerAvailability",
    "ecr:BatchGetImage",
    "ecr:GetDownloadUrlForLayer",
  ]

  create_policy = length(var.ci_principal_arns) + length(var.pull_principal_arns) > 0
}
