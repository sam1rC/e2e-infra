resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.trail_name}"
  retention_in_days = local.cloudwatch_retention
  kms_key_id        = module.kms.key_arn

  tags = var.tags
}

data "aws_iam_policy_document" "cloudtrail_logs_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_logs" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:*"]
  }
}

resource "aws_iam_role" "cloudtrail_logs" {
  name               = "${local.name}-cloudtrail-to-logs"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_logs_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  name   = "put-log-events"
  role   = aws_iam_role.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_logs.json
}

resource "aws_cloudtrail" "this" {
  name                          = local.trail_name
  s3_bucket_name                = local.log_bucket_name
  kms_key_id                    = local.log_kms_key_arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_logs.arn

  advanced_event_selector {
    name = "Management events (lectura y escritura)"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  dynamic "advanced_event_selector" {
    for_each = var.cloudtrail.s3_data_events ? [1] : []

    content {
      name = "S3 data events"

      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }

      field_selector {
        field  = "resources.type"
        equals = ["AWS::S3::Object"]
      }
    }
  }

  tags = var.tags

  depends_on = [module.log_bucket, module.kms, aws_iam_role_policy.cloudtrail_logs]
}
