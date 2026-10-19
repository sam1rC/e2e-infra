resource "aws_cloudwatch_log_group" "exec" {
  count = local.enable_exec ? 1 : 0

  name              = "/aws/ecs/${local.name}/exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Log group de Container Insights creado antes que el cluster, con la CMK y retención: si no, ECS lo crea sin
# cifrar y sin caducidad (y sobrevive al destroy; detectado en la sandbox el 2026-10-14).
resource "aws_cloudwatch_log_group" "container_insights" {
  count = var.container_insights == "disabled" ? 0 : 1

  name              = "/aws/ecs/containerinsights/${local.name}/performance"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_ecs_cluster" "this" {
  #checkov:skip=CKV_AWS_65:Container Insights es enhanced por defecto y el módulo prohíbe disabled en prod; checkov no evalúa el valor cuando el llamador lo calcula a partir de variables (falso positivo en las raíces de live/).
  name = local.name

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  configuration {
    dynamic "execute_command_configuration" {
      for_each = local.enable_exec ? [1] : []

      content {
        kms_key_id = var.kms_key_arn
        logging    = "OVERRIDE"

        log_configuration {
          cloud_watch_encryption_enabled = true
          cloud_watch_log_group_name     = aws_cloudwatch_log_group.exec[0].name
        }
      }
    }

    dynamic "managed_storage_configuration" {
      for_each = var.ephemeral_storage_kms_key_arn == null ? [] : [var.ephemeral_storage_kms_key_arn]

      content {
        fargate_ephemeral_storage_kms_key_id = managed_storage_configuration.value
      }
    }
  }

  tags = merge(var.tags, { Name = local.name })

  depends_on = [aws_cloudwatch_log_group.container_insights]
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = local.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = local.default_strategy

    content {
      capacity_provider = default_capacity_provider_strategy.key
      base              = default_capacity_provider_strategy.value.base
      weight            = default_capacity_provider_strategy.value.weight
    }
  }
}
