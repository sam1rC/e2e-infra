provider "aws" {
  region = "us-east-1"
}

variable "name_suffix" {
  description = "Sufijo para nombres de la prueba (evita colisiones en ejecuciones paralelas)."
  type        = string
  default     = "example"
  nullable    = false
}

data "aws_caller_identity" "current" {}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "data"
  via_services = [
    "s3.us-east-1.amazonaws.com",
  ]
}

module "bucket" {
  source = "../.."

  project       = "acme"
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "acme-dev-data-${data.aws_caller_identity.current.account_id}-${var.name_suffix}"
  kms_key_arn   = module.kms.key_arn
  force_destroy = true # solo porque es un ejemplo efímero

  deny_unencrypted_uploads = true

  lifecycle_config = {
    transition_to_ia_days           = 30
    transition_to_glacier_days      = 90
    expiration_days                 = 730
    noncurrent_expiration_days      = 90
    noncurrent_versions_to_keep     = 3
    abort_incomplete_multipart_days = 7
  }

  policy_statements = [
    {
      sid     = "AllowAccountReadOfReports"
      actions = ["s3:GetObject"]
      resource_paths = [
        "/reports/*",
      ]
      principals = [{
        type        = "AWS"
        identifiers = [data.aws_caller_identity.current.account_id]
      }]
    },
  ]

  tags = {
    Owner = "platform"
  }
}

output "bucket_arn" {
  description = "ARN del bucket."
  value       = module.bucket.bucket_arn
}
