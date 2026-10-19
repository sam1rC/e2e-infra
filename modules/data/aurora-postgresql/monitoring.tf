data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    sid     = "RdsMonitoring"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }

    # Evita el confused deputy: solo RDS actuando en esta cuenta.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Equivale a AmazonRDSEnhancedMonitoringRole, limitado a la cuenta y región (ADR 0012).
data "aws_iam_policy_document" "monitoring" {
  statement {
    sid       = "CreateOsMetricsLogGroup"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:PutRetentionPolicy"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:RDS*"]
  }

  statement {
    sid       = "WriteOsMetrics"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams", "logs:GetLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:RDS*:log-stream:*"]
  }
}

resource "aws_iam_role" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name_prefix        = "${local.name}-mon-"
  description        = "Enhanced Monitoring de ${local.name}"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json

  tags = merge(var.tags, { Name = "${local.name}-monitoring" })
}

resource "aws_iam_role_policy" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name   = "enhanced-monitoring"
  role   = aws_iam_role.monitoring[0].id
  policy = data.aws_iam_policy_document.monitoring.json
}
