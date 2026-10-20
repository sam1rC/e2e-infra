resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-security-alerts"
  kms_master_key_id = module.kms.key_id

  tags = var.tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${local.name}-guardduty-high"
  description = "Hallazgos de GuardDuty con severidad >= 7"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail        = { severity = [{ numeric = [">=", 7] }] }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "securityhub_high" {
  name        = "${local.name}-securityhub-high"
  description = "Hallazgos nuevos de Security Hub con severidad CRITICAL o HIGH"

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity    = { Label = ["CRITICAL", "HIGH"] }
        Workflow    = { Status = ["NEW"] }
        RecordState = ["ACTIVE"]
      }
    }
  })

  tags = var.tags
}

data "aws_iam_policy_document" "alerts_topic" {
  statement {
    sid       = "AllowSecurityRulesToPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.guardduty_high.arn, aws_cloudwatch_event_rule.securityhub_high.arn]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts_topic.json
}

resource "aws_cloudwatch_event_target" "guardduty_high" {
  rule = aws_cloudwatch_event_rule.guardduty_high.name
  arn  = aws_sns_topic.alerts.arn
}

resource "aws_cloudwatch_event_target" "securityhub_high" {
  rule = aws_cloudwatch_event_rule.securityhub_high.name
  arn  = aws_sns_topic.alerts.arn
}
