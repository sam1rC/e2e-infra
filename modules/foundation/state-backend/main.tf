module "kms" {
  source = "../kms-key"

  project     = var.project
  environment = var.environment
  purpose     = "state"
  description = "CMK del estado de OpenTofu de ${var.project}/${var.environment} (bucket y cifrado del bloque encryption)"

  admin_principal_arns = var.kms_admin_principal_arns
  user_principal_arns  = var.kms_user_principal_arns
  via_services         = ["s3.${local.region}.amazonaws.com"]

  tags = var.tags
}

module "bucket" {
  source = "../../storage/s3-bucket"

  project     = var.project
  environment = var.environment
  purpose     = "state"
  bucket_name = local.bucket_name
  kms_key_arn = module.kms.key_arn

  object_lock = var.object_lock_days == null ? null : { days = var.object_lock_days }

  lifecycle_config = {
    noncurrent_expiration_days = var.noncurrent_version_retention_days
  }

  tags = var.tags
}
