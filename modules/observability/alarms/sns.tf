data "aws_iam_policy_document" "topic" {
  count = local.create_topic ? 1 : 0

  statement {
    sid       = "AllowServicesToPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this[0].arn]

    principals {
      type        = "Service"
      identifiers = var.publisher_service_principals
    }

    # Evita el confused deputy: solo servicios actuando en esta cuenta.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowAccountToManage"
    effect = "Allow"
    actions = [
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:ListSubscriptionsByTopic",
      "sns:Publish",
    ]
    resources = [aws_sns_topic.this[0].arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # SNS no admite el comodín "sns:*" en las políticas de tema ("Policy statement action out of service scope",
  # comprobado contra AWS): se enumeran todas las acciones de nivel de tema.
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    actions = [
      "sns:AddPermission",
      "sns:DeleteTopic",
      "sns:GetDataProtectionPolicy",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTagsForResource",
      "sns:Publish",
      "sns:PutDataProtectionPolicy",
      "sns:RemovePermission",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
    ]
    resources = [aws_sns_topic.this[0].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic" "this" {
  count = local.create_topic ? 1 : 0

  name              = "${local.name}-alarms"
  display_name      = "${local.name} alarms"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, { Name = "${local.name}-alarms" })
}

resource "aws_sns_topic_policy" "this" {
  count = local.create_topic ? 1 : 0

  arn    = aws_sns_topic.this[0].arn
  policy = data.aws_iam_policy_document.topic[0].json
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_subscriptions)

  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# El topic pasó a ser opcional (existing_topic_arn): las instancias ya desplegadas conservan el suyo.
moved {
  from = aws_sns_topic.this
  to   = aws_sns_topic.this[0]
}

moved {
  from = aws_sns_topic_policy.this
  to   = aws_sns_topic_policy.this[0]
}
