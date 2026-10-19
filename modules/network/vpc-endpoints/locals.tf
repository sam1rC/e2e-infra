locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  service_prefix = "com.amazonaws.${local.region}"

  s3_allowed_accounts = distinct(concat([local.account_id], var.s3_allowed_account_ids))

  # Bucket de AWS desde el que ECR sirve las capas de las imágenes (necesario para docker pull sin NAT).
  ecr_layer_bucket_arn = "arn:${local.partition}:s3:::prod-${local.region}-starport-layer-bucket"
}
