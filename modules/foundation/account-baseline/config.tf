data "aws_iam_policy_document" "config_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

data "aws_iam_policy_document" "config_delivery" {
  statement {
    sid       = "DeliverToLogBucket"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:PutObjectAcl"]
    resources = ["arn:${local.partition}:s3:::${local.log_bucket_name}/AWSLogs/${local.account_id}/Config/*"]

    condition {
      test     = "StringLike"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "CheckLogBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:${local.partition}:s3:::${local.log_bucket_name}"]
  }

  statement {
    sid       = "UseLogKey"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [local.log_kms_key_arn]
  }
}

resource "aws_iam_role" "config" {
  name               = "${local.name}-aws-config"
  assume_role_policy = data.aws_iam_policy_document.config_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_delivery" {
  name   = "deliver-to-log-bucket"
  role   = aws_iam_role.config.id
  policy = data.aws_iam_policy_document.config_delivery.json
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${local.name}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${local.name}-delivery"
  s3_bucket_name = local.log_bucket_name
  s3_kms_key_arn = local.log_kms_key_arn

  depends_on = [aws_config_configuration_recorder.this, module.log_bucket, aws_iam_role_policy.config_delivery]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
