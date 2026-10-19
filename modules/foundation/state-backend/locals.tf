locals {
  bucket_name = "${var.project}-${var.environment}-tfstate-${data.aws_caller_identity.current.account_id}"
  region      = data.aws_region.current.region
}
