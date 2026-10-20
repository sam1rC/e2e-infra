resource "aws_cloudwatch_event_bus" "this" {
  name               = local.name
  description        = "Bus de eventos de ${var.project} (${var.environment})"
  kms_key_identifier = var.kms_key_arn

  tags = merge(var.tags, { Name = local.name })
}

# Permite reproducir (replay) eventos pasados tras un incidente o un fallo de entrega.
resource "aws_cloudwatch_event_archive" "this" {
  count = var.archive_retention_days > 0 ? 1 : 0

  name               = local.name
  description        = "Archivo de ${local.name}"
  event_source_arn   = aws_cloudwatch_event_bus.this.arn
  retention_days     = var.archive_retention_days
  kms_key_identifier = var.kms_key_arn
}

resource "aws_cloudwatch_event_bus_policy" "publishers" {
  count = length(var.publisher_account_ids) > 0 ? 1 : 0

  event_bus_name = aws_cloudwatch_event_bus.this.name
  policy         = data.aws_iam_policy_document.publishers[0].json
}

data "aws_iam_policy_document" "publishers" {
  count = length(var.publisher_account_ids) > 0 ? 1 : 0

  statement {
    sid       = "AllowPutEventsFromListedAccounts"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.this.arn]

    principals {
      type        = "AWS"
      identifiers = [for a in var.publisher_account_ids : "arn:${data.aws_partition.current.partition}:iam::${a}:root"]
    }
  }
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each = var.rules

  name           = "${local.name}-${each.key}"
  description    = each.value.description == "" ? "Reglas ${each.key} de ${local.name}" : each.value.description
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern  = local.rule_patterns[each.key]
  state          = "ENABLED"

  tags = merge(var.tags, { Name = "${local.name}-${each.key}" })
}

resource "aws_cloudwatch_event_target" "firehose" {
  for_each = var.rules

  rule           = aws_cloudwatch_event_rule.this[each.key].name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id      = each.key
  arn            = each.value.firehose_arn
  role_arn       = aws_iam_role.events_to_firehose[0].arn

  retry_policy {
    maximum_retry_attempts       = var.retry_policy.maximum_retry_attempts
    maximum_event_age_in_seconds = var.retry_policy.maximum_event_age_in_seconds
  }

  dead_letter_config {
    arn = aws_sqs_queue.dlq[each.key].arn
  }
}
