# Logging estándar v2 (CloudWatch vended logs hacia S3): no necesita ACL en el bucket, a diferencia
# del logging clásico, incompatible con BucketOwnerEnforced. Debe crearse en us-east-1.
resource "aws_cloudwatch_log_delivery_source" "this" {
  count = local.access_logs ? 1 : 0

  name         = "${local.name}-cloudfront"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this.arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "this" {
  count = local.access_logs ? 1 : 0

  name          = "${local.name}-cloudfront-s3"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = var.log_bucket_arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "this" {
  count = local.access_logs ? 1 : 0

  delivery_source_name     = aws_cloudwatch_log_delivery_source.this[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.this[0].arn

  s3_delivery_configuration {
    suffix_path                 = "${var.log_prefix}/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
    enable_hive_compatible_path = false
  }

  tags = var.tags
}
