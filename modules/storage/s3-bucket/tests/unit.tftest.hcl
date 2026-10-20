mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  purpose     = "data"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "acme-dev-data-123456789012"
    error_message = "El nombre por defecto debe ser <project>-<environment>-<purpose>-<account_id>."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy debe ser false por defecto."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "Block Public Access debe estar completamente activado."
  }

  assert {
    condition     = alltrue([for r in aws_s3_bucket_ownership_controls.this.rule : r.object_ownership == "BucketOwnerEnforced"])
    error_message = "Ownership debe ser BucketOwnerEnforced."
  }

  assert {
    condition     = alltrue([for v in aws_s3_bucket_versioning.this.versioning_configuration : v.status == "Enabled"])
    error_message = "El versionado debe estar activado."
  }
}

run "encrypts_with_kms_and_bucket_key" {
  command = plan

  assert {
    condition = alltrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      r.bucket_key_enabled == true &&
      alltrue([for d in r.apply_server_side_encryption_by_default : d.sse_algorithm == "aws:kms" && d.kms_master_key_id == var.kms_key_arn])
    ])
    error_message = "Debe cifrar con aws:kms, la CMK indicada y bucket key activada."
  }
}

run "sse_s3_for_services_without_kms" {
  command = plan

  variables {
    purpose       = "logs"
    sse_algorithm = "AES256"
    kms_key_arn   = null
  }

  assert {
    condition = alltrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      r.bucket_key_enabled == false &&
      alltrue([for d in r.apply_server_side_encryption_by_default : d.sse_algorithm == "AES256"])
    ])
    error_message = "Con AES256 debe usarse SSE-S3 sin bucket key."
  }
}

run "default_lifecycle_cleans_multipart_and_old_versions" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 1
    error_message = "Debe existir la regla de ciclo de vida por defecto."
  }

  assert {
    condition = alltrue([
      for r in aws_s3_bucket_lifecycle_configuration.this[0].rule :
      alltrue([for a in r.abort_incomplete_multipart_upload : a.days_after_initiation == 7]) &&
      alltrue([for n in r.noncurrent_version_expiration : n.noncurrent_days == 90])
    ])
    error_message = "Multipart a 7 días y versiones no actuales a 90 días por defecto."
  }
}

run "lifecycle_transitions_follow_inputs" {
  command = plan

  variables {
    lifecycle_config = {
      transition_to_ia_days      = 30
      transition_to_glacier_days = 90
    }
  }

  assert {
    condition = alltrue([
      for r in aws_s3_bucket_lifecycle_configuration.this[0].rule :
      toset([for t in r.transition : t.storage_class]) == toset(["STANDARD_IA", "GLACIER"])
    ])
    error_message = "Deben configurarse las transiciones a STANDARD_IA y GLACIER."
  }
}

run "object_lock_only_when_requested" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_object_lock_configuration.this) == 0 && aws_s3_bucket.this.object_lock_enabled == false
    error_message = "Object Lock debe estar desactivado por defecto."
  }
}

run "object_lock_enabled" {
  command = plan

  variables {
    purpose     = "state"
    object_lock = { days = 14 }
  }

  assert {
    condition     = length(aws_s3_bucket_object_lock_configuration.this) == 1 && aws_s3_bucket.this.object_lock_enabled == true
    error_message = "Object Lock debe activarse cuando se pide."
  }
}

run "access_logging_optional" {
  command = plan

  variables {
    access_logging = { target_bucket = "acme-prod-logs-123456789012" }
  }

  assert {
    condition     = length(aws_s3_bucket_logging.this) == 1 && aws_s3_bucket_logging.this[0].target_prefix == "acme-dev-data-123456789012/"
    error_message = "Con access_logging debe crearse el logging con prefijo por bucket."
  }
}

run "policy_has_tls_denies_and_extras" {
  command = plan

  variables {
    deny_unencrypted_uploads = true
    policy_statements = [{
      sid        = "Extra"
      actions    = ["s3:GetObject"]
      principals = [{ type = "AWS", identifiers = ["123456789012"] }]
    }]
  }

  assert {
    condition     = length(data.aws_iam_policy_document.this.statement) == 4
    error_message = "Debe haber DenyInsecureTransport, DenyOutdatedTls, cabecera de cifrado y la declaración extra."
  }
}

run "rejects_kms_without_key" {
  command = plan

  variables {
    kms_key_arn = null
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_unknown_purpose" {
  command = plan

  variables {
    purpose = "misc"
  }

  expect_failures = [var.purpose]
}

run "rejects_glacier_before_ia" {
  command = plan

  variables {
    lifecycle_config = {
      transition_to_ia_days      = 90
      transition_to_glacier_days = 60
    }
  }

  expect_failures = [var.lifecycle_config]
}

run "rejects_invalid_object_lock_mode" {
  command = plan

  variables {
    object_lock = { mode = "NONE", days = 7 }
  }

  expect_failures = [var.object_lock]
}
