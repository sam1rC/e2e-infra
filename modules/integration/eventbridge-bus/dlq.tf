resource "aws_sqs_queue" "dlq" {
  for_each = var.rules

  name                      = "${local.name}-${each.key}-dlq"
  kms_master_key_id         = var.kms_key_arn
  message_retention_seconds = var.dlq_retention_days * 86400

  tags = merge(var.tags, { Name = "${local.name}-${each.key}-dlq" })
}

data "aws_iam_policy_document" "dlq" {
  for_each = var.rules

  statement {
    sid       = "AllowEventBridgeRuleToSend"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dlq[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.this[each.key].arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.dlq[each.key].arn]

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

resource "aws_sqs_queue_policy" "dlq" {
  for_each = var.rules

  queue_url = aws_sqs_queue.dlq[each.key].url
  policy    = data.aws_iam_policy_document.dlq[each.key].json
}
