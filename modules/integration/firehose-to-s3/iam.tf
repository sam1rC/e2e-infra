data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "FirehoseAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    # Evita el confused deputy: solo este stream, en esta cuenta.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.stream_arn]
    }
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "WriteObjectsToBucket"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [var.bucket_arn, "${var.bucket_arn}/*"]
  }

  # S3 cifra con la CMK (ViaService s3) y Firehose descifra su búfer en reposo (ViaService firehose).
  statement {
    sid       = "UseKeyThroughS3AndFirehose"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "s3.${data.aws_region.current.region}.amazonaws.com",
        "firehose.${data.aws_region.current.region}.amazonaws.com",
      ]
    }
  }

  statement {
    sid       = "WriteDeliveryErrorLogs"
    effect    = "Allow"
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:log-stream:${local.log_stream_name}"]
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = "${local.stream_name}-"
  description        = "Entrega de ${local.stream_name} a S3"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(var.tags, { Name = local.stream_name })
}

resource "aws_iam_role_policy" "this" {
  name   = "deliver-to-s3"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}
