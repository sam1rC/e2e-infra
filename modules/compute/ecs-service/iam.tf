# --- Execution role: lo usa ECS (no la aplicación) para descargar la imagen, escribir logs y leer los secretos ----
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    sid     = "EcsTasksAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    # Confused deputy: solo tareas de esta cuenta.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:ecs:${local.region}:${local.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name                 = "${local.name}-exec"
  description          = "Execution role de ECS para ${local.name}: imagen, logs y secretos declarados"
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume.json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, { Name = "${local.name}-exec" })
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "WriteServiceLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  # GetAuthorizationToken no admite recursos concretos.
  statement {
    sid       = "EcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(local.ecr_repository_arns) > 0 ? [1] : []

    content {
      sid    = "PullImages"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
      resources = local.ecr_repository_arns
    }
  }

  dynamic "statement" {
    for_each = length(local.secret_arns_manager) > 0 ? [1] : []

    content {
      sid       = "ReadDeclaredSecrets"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = local.secret_arns_manager
    }
  }

  dynamic "statement" {
    for_each = length(local.secret_arns_ssm) > 0 ? [1] : []

    content {
      sid       = "ReadDeclaredParameters"
      effect    = "Allow"
      actions   = ["ssm:GetParameters"]
      resources = local.secret_arns_ssm
    }
  }

  dynamic "statement" {
    for_each = length(var.secrets_kms_key_arns) > 0 && length(var.secrets) > 0 ? [1] : []

    content {
      sid       = "DecryptDeclaredSecrets"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = var.secrets_kms_key_arns

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values = [
          "secretsmanager.${local.region}.amazonaws.com",
          "ssm.${local.region}.amazonaws.com",
        ]
      }
    }
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "execution"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

# --- Task role: la identidad de la aplicación. Vacío por defecto ------------------------------------------------
resource "aws_iam_role" "task" {
  name                 = "${local.name}-task"
  description          = "Task role de ${local.name}: sin permisos salvo los inyectados"
  assume_role_policy   = data.aws_iam_policy_document.ecs_tasks_assume.json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, { Name = "${local.name}-task" })
}

resource "aws_iam_role_policy" "task_injected" {
  for_each = var.task_role_policies

  name   = each.key
  role   = aws_iam_role.task.id
  policy = each.value
}

# Sidecar ADOT: trazas a X-Ray y métricas EMF al log group del servicio.
data "aws_iam_policy_document" "otel" {
  count = local.otel_enabled ? 1 : 0

  # X-Ray no admite permisos por recurso en la escritura de trazas.
  statement {
    sid       = "SendTraces"
    effect    = "Allow"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  statement {
    sid       = "SendMetricsAsLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "task_otel" {
  count = local.otel_enabled ? 1 : 0

  name   = "otel-collector"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.otel[0].json
}

# ECS Exec abre el canal con el agente SSM desde la propia tarea.
data "aws_iam_policy_document" "exec_channel" {
  count = var.enable_exec ? 1 : 0

  statement {
    sid    = "EcsExecChannel"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_exec_channel" {
  count = var.enable_exec ? 1 : 0

  name   = "ecs-exec"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.exec_channel[0].json
}
