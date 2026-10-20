provider "aws" {
  region = "us-east-1"
}

module "kms" {
  source = "../../../../foundation/kms-key"

  project     = "acme"
  environment = "dev"
  purpose     = "data"

  service_principals = ["logs.us-east-1.amazonaws.com", "events.amazonaws.com", "sqs.amazonaws.com"]
  via_services = [
    "s3.us-east-1.amazonaws.com",
    "firehose.us-east-1.amazonaws.com",
  ]
}

module "bucket" {
  source = "../../../../storage/s3-bucket"

  project       = "acme"
  environment   = "dev"
  purpose       = "data"
  kms_key_arn   = module.kms.key_arn
  force_destroy = true # solo porque es un ejemplo efímero
}

module "firehose" {
  source = "../.."

  project     = "acme"
  environment = "dev"
  bucket_arn  = module.bucket.bucket_arn
  kms_key_arn = module.kms.key_arn

  publish_ssm_parameters = false
}

output "delivery_stream_arn" {
  description = "ARN del delivery stream."
  value       = module.firehose.delivery_stream_arn
}
