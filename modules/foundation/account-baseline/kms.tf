data "aws_iam_policy_document" "key_services" {
  statement {
    sid       = "AllowCloudTrailEncrypt"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${local.partition}:cloudtrail:*:${local.account_id}:trail/*"]
    }
  }

  statement {
    sid       = "AllowCloudTrailDescribeKey"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowCloudWatchLogs"
    effect    = "Allow"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:*"]
    }
  }

  # EventBridge publica en el tópico SNS cifrado; no envía aws:SourceAccount, así que
  # se acota con la política del tópico (aws:SourceArn de las dos reglas).
  statement {
    sid       = "AllowEventBridgeToEncryptedTopic"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

module "kms" {
  source = "../kms-key"

  project     = var.project
  environment = var.environment
  purpose     = "baseline"
  description = "CMK de la línea base de ${var.project}/${var.environment}: logs de seguridad, alertas y volúmenes EBS"

  via_services                = ["ec2.${local.region}.amazonaws.com"]
  additional_policy_documents = [data.aws_iam_policy_document.key_services.json]

  tags = var.tags
}
