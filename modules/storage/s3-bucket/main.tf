resource "aws_s3_bucket" "this" {
  bucket              = local.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock != null

  tags = merge(var.tags, { Name = local.bucket_name })
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = local.use_kms

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = local.use_kms ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.object_lock == null ? 0 : 1

  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode = var.object_lock.mode
      days = var.object_lock.days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = local.lifecycle_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "default"
    status = "Enabled"

    filter {}

    dynamic "transition" {
      for_each = local.transitions

      content {
        storage_class = transition.key
        days          = transition.value
      }
    }

    dynamic "expiration" {
      for_each = var.lifecycle_config.expiration_days == null ? [] : [var.lifecycle_config.expiration_days]

      content {
        days = expiration.value
      }
    }

    dynamic "noncurrent_version_expiration" {
      for_each = var.lifecycle_config.noncurrent_expiration_days == null ? [] : [1]

      content {
        noncurrent_days           = var.lifecycle_config.noncurrent_expiration_days
        newer_noncurrent_versions = var.lifecycle_config.noncurrent_versions_to_keep
      }
    }

    dynamic "abort_incomplete_multipart_upload" {
      for_each = var.lifecycle_config.abort_incomplete_multipart_days == null ? [] : [var.lifecycle_config.abort_incomplete_multipart_days]

      content {
        days_after_initiation = abort_incomplete_multipart_upload.value
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_logging" "this" {
  count = var.access_logging == null ? 0 : 1

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_logging.target_bucket
  target_prefix = coalesce(var.access_logging.target_prefix, "${local.bucket_name}/")
}

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

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

  statement {
    sid       = "DenyOutdatedTls"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }

  dynamic "statement" {
    for_each = var.deny_unencrypted_uploads ? [1] : []

    content {
      sid       = "DenyWrongEncryptionHeader"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      # IfExists: las subidas sin cabecera no se deniegan, las cifra el cifrado por defecto del bucket.
      condition {
        test     = "StringNotEqualsIfExists"
        variable = "s3:x-amz-server-side-encryption"
        values   = [var.sse_algorithm]
      }
    }
  }

  dynamic "statement" {
    for_each = { for s in var.policy_statements : s.sid => s }

    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = [for p in statement.value.resource_paths : "${aws_s3_bucket.this.arn}${p}"]

      dynamic "principals" {
        for_each = statement.value.principals

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = statement.value.conditions

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json

  # El bloqueo de acceso público debe existir antes que la política para evitar carreras de aplicación.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
