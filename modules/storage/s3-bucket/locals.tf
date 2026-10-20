locals {
  bucket_name = coalesce(var.bucket_name, "${var.project}-${var.environment}-${var.purpose}-${data.aws_caller_identity.current.account_id}")
  use_kms     = var.sse_algorithm == "aws:kms"

  lifecycle_enabled = (
    var.lifecycle_config.transition_to_ia_days != null ||
    var.lifecycle_config.transition_to_glacier_days != null ||
    var.lifecycle_config.expiration_days != null ||
    var.lifecycle_config.noncurrent_expiration_days != null ||
    var.lifecycle_config.abort_incomplete_multipart_days != null
  )

  transitions = merge(
    var.lifecycle_config.transition_to_ia_days == null ? {} : { STANDARD_IA = var.lifecycle_config.transition_to_ia_days },
    var.lifecycle_config.transition_to_glacier_days == null ? {} : { GLACIER = var.lifecycle_config.transition_to_glacier_days },
  )
}
