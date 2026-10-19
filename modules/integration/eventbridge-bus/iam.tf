data "aws_iam_policy_document" "events_assume" {
  statement {
    sid     = "EventsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    # Evita el confused deputy: solo las reglas de este bus, en esta cuenta.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = values(local.rule_arns)
    }
  }
}

data "aws_iam_policy_document" "events_to_firehose" {
  statement {
    sid       = "PutRecordsToDeclaredStreams"
    effect    = "Allow"
    actions   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
    resources = local.firehose_arns
  }

  dynamic "statement" {
    for_each = length(var.target_kms_key_arns) > 0 ? [1] : []

    content {
      sid       = "UseTargetStreamKeys"
      effect    = "Allow"
      actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
      resources = var.target_kms_key_arns

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["firehose.${data.aws_region.current.region}.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role" "events_to_firehose" {
  count = length(var.rules) > 0 ? 1 : 0

  name_prefix        = "${local.name}-fh-"
  description        = "Permite a las reglas de ${local.name} escribir en Data Firehose"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json

  tags = merge(var.tags, { Name = "${local.name}-events-to-firehose" })
}

resource "aws_iam_role_policy" "events_to_firehose" {
  count = length(var.rules) > 0 ? 1 : 0

  name   = "put-records"
  role   = aws_iam_role.events_to_firehose[0].id
  policy = data.aws_iam_policy_document.events_to_firehose.json
}
