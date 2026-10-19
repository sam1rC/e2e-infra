data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    # Confused deputy: solo Lambda actuando para esta cuenta. Sin aws:SourceArn: la documentación de Lambda
    # no lo garantiza para roles de ejecución (pendiente de verificar en la prueba de integración).
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = local.function_name
  description          = "Rol de ejecucion de ${local.function_name}: logs, trazas y lo inyectado"
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, { Name = local.function_name })
}

# Equivale a AWSLambdaBasicExecutionRole (+ VPC/X-Ray/DLQ si se piden) pero acotada: la gestionada permite
# logs:* sobre "*"; aquí los logs solo van al log group de la función, que crea el módulo.
data "aws_iam_policy_document" "base" {
  statement {
    sid       = "WriteFunctionLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  # X-Ray no admite permisos por recurso en la escritura de trazas.
  statement {
    sid       = "SendTraces"
    effect    = "Allow"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  # Descifrar las variables de entorno cifradas con la CMK.
  statement {
    sid       = "DecryptEnvironment"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  # Las acciones de interfaces de red de Lambda en VPC no admiten permisos por recurso.
  dynamic "statement" {
    for_each = var.vpc_config == null ? [] : [1]

    content {
      sid    = "ManageVpcNetworkInterfaces"
      effect = "Allow"
      actions = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_dlq ? [1] : []

    content {
      sid       = "SendToDeadLetterQueue"
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.dlq[0].arn]
    }
  }

  dynamic "statement" {
    for_each = var.enable_dlq ? [1] : []

    content {
      sid       = "EncryptDeadLetterMessages"
      effect    = "Allow"
      actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "base" {
  name   = "base"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.base.json
}

resource "aws_iam_role_policy" "injected" {
  for_each = var.policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}
