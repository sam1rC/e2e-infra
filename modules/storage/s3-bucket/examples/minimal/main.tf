provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "data"
}

module "bucket" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  purpose     = "data"
  kms_key_arn = module.kms.key_arn
}

output "bucket_arn" {
  description = "ARN del bucket."
  value       = module.bucket.bucket_arn
}
